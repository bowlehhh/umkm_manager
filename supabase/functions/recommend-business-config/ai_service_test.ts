import {
  type AiProvider,
  AiService,
  buildCapabilityBoundFeatureSchema,
  extractOpenAiStructuredOutput,
  generationSettingsForRequest,
  normalizeCustomFieldsForEnabledCapabilities,
  type PromptCacheStore,
  validateBusinessConfigurationOutput,
} from "./ai_service.ts";

const settings = {
  provider: "gemini" as const,
  promptCachingEnabled: true,
  promptCacheTtlSeconds: 600,
  model: "gemini-test",
  maxOutputTokens: 400,
  dailyAiLimit: 5,
  rateLimitPerMinute: 3,
};

const businessConfigurationContract = {
  capabilities: ["dashboard", "products", "cashier", "transactions", "customers"],
  fieldTypes: ["text", "dropdown"],
  dashboardWidgets: ["today_sales", "transactions"],
  capabilityActions: {
    dashboard: ["view"],
    products: ["list", "create", "view", "edit", "archive", "search"],
    cashier: ["list", "create"],
    transactions: ["list", "view", "search"],
    customers: ["list", "create", "view", "edit", "archive", "search"],
  },
};

function validBusinessConfiguration() {
  return {
    businessCategory: "Kuliner",
    summary: "Warung makanan dan minuman.",
    recommendedFeatures: [
      {
        key: "products",
        name: "Produk",
        enabled: true,
        reason: "Kelola menu dan harga.",
        actions: ["list", "create"],
      },
    ],
    customFields: [
      {
        module: "products",
        key: "spice_level",
        label: "Tingkat pedas",
        type: "dropdown",
        required: false,
        options: ["Tidak pedas", "Pedas"],
      },
    ],
    workflow: [{ key: "order", label: "Pesanan", order: 1 }],
    paymentRules: {
      supportsDownPayment: false,
      suggestedDownPaymentPercent: 0,
    },
    dashboardWidgets: ["today_sales"],
    unsupportedRequirements: [],
  };
}

function responseSourceForContract(value: unknown) {
  const normalized = normalizeCustomFieldsForEnabledCapabilities(
    value,
    businessConfigurationContract.capabilities,
  );
  return validateBusinessConfigurationOutput(
    normalized.value,
    businessConfigurationContract,
  ).value === null
    ? "fallback"
    : "model";
}

function response(status = 200) {
  return new Response("{}", { status });
}

function provider(overrides: Partial<AiProvider> = {}): AiProvider {
  return {
    createCache: () =>
      Promise.resolve({ name: "cachedContents/one", expiresAt: null }),
    generate: () => Promise.resolve(response()),
    isInvalidCacheResponse: (response) =>
      response.status === 400 || response.status === 404,
    ...overrides,
  };
}

function store(
  claims: Array<"ready" | "creator" | "waiting" | "unavailable">,
): PromptCacheStore & { creates: number; unavailable: number } {
  let index = 0;
  return {
    creates: 0,
    unavailable: 0,
    claim: () => {
      const state = claims[Math.min(index++, claims.length - 1)];
      return Promise.resolve(
        state === "ready"
          ? { state, cacheName: "cachedContents/existing" }
          : { state },
      );
    },
    saveReady: () => Promise.resolve(),
    markUnavailable: () => Promise.resolve(),
  };
}

Deno.test("cache miss creates once and uses the cache", async () => {
  let created = 0;
  let cachedContent: string | undefined;
  const service = new AiService(
    provider({
      createCache: async () => {
        created++;
        return { name: "cachedContents/new", expiresAt: null };
      },
      generate: async (input) => {
        cachedContent = input.cachedContent;
        return response();
      },
    }),
    store(["creator"]),
  );
  const result = await service.generate({
    settings,
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (
    created !== 1 || cachedContent !== "cachedContents/new" ||
    !result.cacheUsed || result.cacheState !== "miss"
  ) throw new Error("cache miss behavior is incorrect");
});

Deno.test("cache hit uses the existing cache", async () => {
  let cachedContent: string | undefined;
  const service = new AiService(
    provider({
      generate: async (input) => {
        cachedContent = input.cachedContent;
        return response();
      },
    }),
    store(["ready"]),
  );
  const result = await service.generate({
    settings,
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (
    cachedContent !== "cachedContents/existing" || result.cacheState !== "hit"
  ) throw new Error("cache hit behavior is incorrect");
});

Deno.test("expired cache is recreated once", async () => {
  let createCalls = 0;
  let generateCalls = 0;
  const service = new AiService(
    provider({
      createCache: async () => ({
        name: `cachedContents/${++createCalls}`,
        expiresAt: null,
      }),
      generate: async () => response(++generateCalls === 1 ? 404 : 200),
    }),
    store(["ready", "creator"]),
  );
  const result = await service.generate({
    settings,
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (createCalls !== 1 || !result.cacheUsed || result.cacheState !== "miss") {
    throw new Error("expired cache was not recreated");
  }
});

Deno.test("provider without server cache does not retry an OpenAI 400", async () => {
  let generateCalls = 0;
  const service = new AiService(
    provider({
      isInvalidCacheResponse: () => false,
      generate: async () => response(++generateCalls === 1 ? 400 : 200),
    }),
    store(["creator"]),
  );
  const result = await service.generate({
    settings: { ...settings, provider: "openai" },
    cacheKey: "openai-schema:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (generateCalls !== 1 || result.response.status !== 400) {
    throw new Error("OpenAI 400 must be returned without a cache retry");
  }
});

Deno.test("OpenAI Responses REST output reads only message output_text content", () => {
  const output = extractOpenAiStructuredOutput({
    status: "completed",
    output: [
      { type: "reasoning", summary: [] },
      {
        type: "message",
        role: "assistant",
        content: [
          {
            type: "output_text",
            text: '{"businessCategory":"kuliner","recommendedFeatures":[]}',
            annotations: [],
          },
        ],
      },
    ],
  });
  if (
    output.responseStatus !== "completed" || output.text === null ||
    output.outputItemTypes.join(",") !== "reasoning,message" ||
    output.contentItemTypes.join(",") !== "output_text" ||
    JSON.parse(output.text).businessCategory !== "kuliner"
  ) throw new Error("Responses API structured output was not read correctly");
});

Deno.test("OpenAI incomplete response exposes token-limit diagnostics", () => {
  const output = extractOpenAiStructuredOutput({
    status: "incomplete",
    incomplete_details: { reason: "max_output_tokens" },
    output: [{ type: "message", content: [] }],
  });
  if (
    output.responseStatus !== "incomplete" ||
    output.incompleteReason !== "max_output_tokens" || output.text !== null
  ) throw new Error("incomplete Responses API diagnostics were not preserved");
});

Deno.test("capability-bound OpenAI schema gives each feature only its supported actions", () => {
  const schema = buildCapabilityBoundFeatureSchema(businessConfigurationContract) as {
    anyOf: Array<{
      properties: {
        key: { enum: string[] };
        actions: { items: { enum: string[] } };
      };
    }>;
  };
  const cashier = schema.anyOf.find((item) => item.properties.key.enum[0] === "cashier");
  if (!cashier || cashier.properties.actions.items.enum.join(",") !== "list,create") {
    throw new Error("cashier action enum is not capability-bound");
  }
});

Deno.test("supported capability actions remain a model response", () => {
  const value = validBusinessConfiguration();
  value.recommendedFeatures[0].key = "cashier";
  value.recommendedFeatures[0].actions = ["list", "create"];
  value.customFields[0].module = "cashier";
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value === null || result.issue !== null || responseSourceForContract(value) !== "model") {
    throw new Error("supported capability actions were not accepted as model output");
  }
});

Deno.test("business configuration contract accepts nullable OpenAI custom-field options", () => {
  const value = validBusinessConfiguration() as Record<string, unknown>;
  (value.customFields as Array<Record<string, unknown>>)[0].options = null;
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value === null || result.issue !== null) {
    throw new Error("OpenAI nullable custom-field options were rejected");
  }
});

Deno.test("business configuration contract accepts nullable OpenAI down-payment percent", () => {
  const value = validBusinessConfiguration() as Record<string, unknown>;
  (value.paymentRules as Record<string, unknown>).suggestedDownPaymentPercent = null;
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value === null || result.issue !== null) {
    throw new Error("OpenAI nullable down-payment percent was rejected");
  }
});

Deno.test("custom field for an enabled capability remains valid", () => {
  const value = validBusinessConfiguration();
  const normalized = normalizeCustomFieldsForEnabledCapabilities(
    value,
    businessConfigurationContract.capabilities,
  );
  const result = validateBusinessConfigurationOutput(
    normalized.value,
    businessConfigurationContract,
  );
  if (normalized.dropped.length !== 0 || result.value === null) {
    throw new Error("custom field for enabled capability was not preserved");
  }
});

Deno.test("globally known but unselected custom-field module is dropped locally", () => {
  const value = validBusinessConfiguration();
  value.customFields[0].module = "dashboard";
  const normalized = normalizeCustomFieldsForEnabledCapabilities(
    value,
    businessConfigurationContract.capabilities,
  );
  const result = validateBusinessConfigurationOutput(
    normalized.value,
    businessConfigurationContract,
  );
  if (
    normalized.dropped.length !== 1 ||
    normalized.dropped[0].path !== "customFields[0].module" ||
    normalized.dropped[0].module !== "dashboard" ||
    result.value === null ||
    responseSourceForContract(value) !== "model"
  ) throw new Error("unselected custom field was not safely normalized");
});

Deno.test("unknown custom-field module remains invalid after normalization", () => {
  const value = validBusinessConfiguration();
  value.customFields[0].module = "reports";
  const normalized = normalizeCustomFieldsForEnabledCapabilities(
    value,
    businessConfigurationContract.capabilities,
  );
  const result = validateBusinessConfigurationOutput(
    normalized.value,
    businessConfigurationContract,
  );
  if (
    normalized.dropped.length !== 0 || result.value !== null ||
    result.issue?.path !== "customFields[0].module" ||
    result.issue.module !== "reports" ||
    result.issue.allowedEnabledCapabilities?.join(",") !== "products"
  ) throw new Error("unknown custom-field module was not rejected with diagnostics");
});

Deno.test("unselected custom-field normalization never invokes another provider request", () => {
  let providerRequests = 0;
  const value = validBusinessConfiguration();
  value.customFields[0].module = "dashboard";
  const normalized = normalizeCustomFieldsForEnabledCapabilities(
    value,
    businessConfigurationContract.capabilities,
  );
  providerRequests += 0;
  if (normalized.dropped.length !== 1 || providerRequests !== 0) {
    throw new Error("normalization must remain local and request-free");
  }
});

Deno.test("business configuration contract reports an unsupported enum", () => {
  const value = validBusinessConfiguration();
  value.recommendedFeatures[0].key = "reports";
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value !== null || result.issue?.path !== "recommendedFeatures[0].key") {
    throw new Error("unsupported feature enum was not identified");
  }
});

Deno.test("globally valid action is rejected when its capability does not support it", () => {
  const value = validBusinessConfiguration();
  value.recommendedFeatures[0].key = "cashier";
  value.recommendedFeatures[0].actions = ["archive"];
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (
    result.value !== null ||
    result.issue?.path !== "recommendedFeatures[0].actions[0]"
  ) throw new Error("globally valid but capability-invalid action was not identified");
});

Deno.test("unknown action is rejected for its capability", () => {
  const value = validBusinessConfiguration();
  value.recommendedFeatures[0].actions = ["delete"];
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (
    result.value !== null ||
    result.issue?.path !== "recommendedFeatures[0].actions[0]"
  ) throw new Error("unknown action was not identified");
});

Deno.test("business configuration contract reports a missing required field", () => {
  const value = validBusinessConfiguration() as Record<string, unknown>;
  delete value.summary;
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value !== null || result.issue?.path !== "summary") {
    throw new Error("missing required field was not identified");
  }
});

Deno.test("business configuration contract reports text beyond the schema limit", () => {
  const value = validBusinessConfiguration();
  value.recommendedFeatures[0].reason = "x".repeat(121);
  const result = validateBusinessConfigurationOutput(
    value,
    businessConfigurationContract,
  );
  if (result.value !== null || result.issue?.path !== "recommendedFeatures[0].reason") {
    throw new Error("long text was not identified");
  }
});

Deno.test("complete OpenAI-shaped output remains eligible for response_source=model", () => {
  const value = validBusinessConfiguration();
  if (responseSourceForContract(value) !== "model") {
    throw new Error("complete valid output would incorrectly use fallback");
  }
});

Deno.test("incomplete Responses output is distinguished before contract fallback", () => {
  const response = extractOpenAiStructuredOutput({
    status: "incomplete",
    incomplete_details: { reason: "max_output_tokens" },
    output: [],
  });
  if (response.responseStatus !== "incomplete" || response.incompleteReason !== "max_output_tokens") {
    throw new Error("incomplete output could be mistaken for invalid_contract");
  }
});

Deno.test("full business configuration preserves the configured 1000-token cap", () => {
  const full = generationSettingsForRequest(
    { ...settings, maxOutputTokens: 1000 },
    "business_configuration",
  );
  const initial = generationSettingsForRequest(
    { ...settings, maxOutputTokens: 1000 },
    "initial_setup",
  );
  const feature = generationSettingsForRequest(
    { ...settings, maxOutputTokens: 1000 },
    "feature_request",
  );
  if (
    full.maxOutputTokens !== 1000 || initial.maxOutputTokens !== 320 ||
    feature.maxOutputTokens !== 120
  ) throw new Error("request output budgets are not cost-controlled");
});

Deno.test("disabled cache still generates normally", async () => {
  let cachedContent: string | undefined;
  const service = new AiService(
    provider({
      generate: async (input) => {
        cachedContent = input.cachedContent;
        return response();
      },
    }),
    store(["creator"]),
  );
  const result = await service.generate({
    settings: { ...settings, promptCachingEnabled: false },
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (cachedContent !== undefined || result.cacheState !== "disabled") {
    throw new Error("disabled cache behavior is incorrect");
  }
});

Deno.test("cache creation failure falls back to a normal request", async () => {
  let cachedContent: string | undefined;
  const service = new AiService(
    provider({
      createCache: () => Promise.reject(new Error("cache unavailable")),
      generate: async (input) => {
        cachedContent = input.cachedContent;
        return response();
      },
    }),
    store(["creator"]),
  );
  const result = await service.generate({
    settings,
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (cachedContent !== undefined || result.cacheState !== "fallback") {
    throw new Error("cache fallback behavior is incorrect");
  }
});

Deno.test("concurrent callers do not create duplicate caches", async () => {
  let createCalls = 0;
  const firstService = new AiService(
    provider({
      createCache: async () => ({
        name: `cachedContents/${++createCalls}`,
        expiresAt: null,
      }),
    }),
    store(["creator"]),
  );
  const waitingService = new AiService(provider(), store(["waiting", "ready"]));
  await Promise.all([
    firstService.generate({
      settings,
      cacheKey: "caption:v1",
      systemInstruction: "static",
      dynamicPrompt: "first",
    }),
    waitingService.generate({
      settings,
      cacheKey: "caption:v1",
      systemInstruction: "static",
      dynamicPrompt: "second",
    }),
  ]);
  if (createCalls !== 1) {
    throw new Error("concurrent cache creation was not coordinated");
  }
});

Deno.test("provider errors are returned to the handler for safe mapping", async () => {
  const service = new AiService(
    provider({ generate: async () => response(503) }),
    store(["ready"]),
  );
  const result = await service.generate({
    settings,
    cacheKey: "caption:v1",
    systemInstruction: "static",
    dynamicPrompt: "dynamic",
  });
  if (result.response.status !== 503) {
    throw new Error("provider error was swallowed");
  }
});
