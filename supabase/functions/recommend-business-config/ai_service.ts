export type CacheState =
  | "disabled"
  | "hit"
  | "miss"
  | "unavailable"
  | "fallback";

export interface AiSettings {
  provider: "gemini" | "openai";
  promptCachingEnabled: boolean;
  promptCacheTtlSeconds: number;
  model: string;
  maxOutputTokens: number;
  dailyAiLimit: number;
  rateLimitPerMinute: number;
}

export interface PromptCache {
  name: string;
  expiresAt: string | null;
}

export type CacheClaim =
  | { state: "ready"; cacheName: string }
  | { state: "creator" }
  | { state: "waiting" }
  | { state: "unavailable" };

export interface AiProvider {
  createCache(input: {
    model: string;
    cacheKey: string;
    systemInstruction: string;
    ttlSeconds: number;
  }): Promise<PromptCache>;
  generate(input: {
    model: string;
    dynamicPrompt: string;
    cachedContent?: string;
    maxOutputTokens: number;
    systemInstruction: string;
    responseJsonSchema?: unknown;
    responseSchemaName?: string;
  }): Promise<Response>;
  /// Only providers with server-side cache resources should treat a response
  /// as an invalid cached-resource response and retry without a cache.
  isInvalidCacheResponse?(response: Response): boolean;
}

export interface PromptCacheStore {
  claim(cacheKey: string, force?: boolean): Promise<CacheClaim>;
  saveReady(input: {
    cacheKey: string;
    cacheName: string;
    model: string;
    expiresAt: string | null;
  }): Promise<void>;
  markUnavailable(cacheKey: string): Promise<void>;
}

export interface AiGeneration {
  response: Response;
  cacheUsed: boolean;
  cacheState: CacheState;
}

export interface OpenAiStructuredOutput {
  responseStatus: string | null;
  incompleteReason: string | null;
  outputItemTypes: string[];
  contentItemTypes: string[];
  text: string | null;
}

export type AiRequestSize =
  | "business_configuration"
  | "initial_setup"
  | "feature_request";

export interface BusinessConfigurationContract {
  capabilities: readonly string[];
  fieldTypes: readonly string[];
  dashboardWidgets: readonly string[];
  capabilityActions: Readonly<Record<string, readonly string[]>>;
}

export interface ContractValidationIssue {
  path: string;
  expected: string;
  actualType: string;
  reason: string;
  module?: string | null;
  allowedEnabledCapabilities?: string[];
}

export type BusinessConfigurationValidation =
  | { value: Record<string, unknown>; issue: null }
  | { value: null; issue: ContractValidationIssue };

export interface DroppedCustomField {
  path: string;
  module: string;
  allowedEnabledCapabilities: string[];
  reason: "module_not_enabled";
}

export interface CustomFieldNormalization {
  value: unknown;
  dropped: DroppedCustomField[];
}

const cacheWaitAttempts = 3;
const cacheWaitMs = 150;

export function buildCacheKey(
  feature: string,
  promptVersion: number,
  schemaVersion: number,
  model: string,
) {
  return `${feature}:prompt-v${promptVersion}:schema-v${schemaVersion}:${model}`;
}

/**
 * The full business configuration uses the server-configured budget. Smaller
 * requests retain conservative caps so increasing the full budget does not
 * increase every AI call.
 */
export function generationSettingsForRequest(
  settings: AiSettings,
  size: AiRequestSize,
): AiSettings {
  const maxOutputTokens = size === "feature_request"
    ? Math.min(settings.maxOutputTokens, 120)
    : size === "initial_setup"
    ? Math.min(settings.maxOutputTokens, 320)
    : settings.maxOutputTokens;
  return maxOutputTokens === settings.maxOutputTokens
    ? settings
    : { ...settings, maxOutputTokens };
}

/**
 * Produces one strict-schema variant per capability. The same action map is
 * supplied to the local validator, so the model's enum cannot drift from the
 * Edge Function contract.
 */
export function buildCapabilityBoundFeatureSchema(
  contract: Pick<BusinessConfigurationContract, "capabilities" | "capabilityActions">,
) {
  return {
    anyOf: contract.capabilities.map((capability) => ({
      type: "object",
      additionalProperties: false,
      required: ["key", "name", "enabled", "reason", "actions"],
      properties: {
        key: { type: "string", enum: [capability] },
        name: { type: "string", maxLength: 14 },
        enabled: { type: "boolean" },
        reason: { type: "string", maxLength: 120 },
        actions: {
          type: "array",
          maxItems: 6,
          items: {
            type: "string",
            enum: contract.capabilityActions[capability] ?? [],
          },
        },
      },
    })),
  };
}

/**
 * A custom field has no valid meaning when its module was not enabled in the
 * same model response. Drop only globally-known, disabled modules; unknown or
 * malformed modules remain for the strict validator to reject.
 */
export function normalizeCustomFieldsForEnabledCapabilities(
  value: unknown,
  capabilities: readonly string[],
): CustomFieldNormalization {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { value, dropped: [] };
  }
  const output = value as Record<string, unknown>;
  if (!Array.isArray(output.recommendedFeatures) || !Array.isArray(output.customFields)) {
    return { value, dropped: [] };
  }
  const enabledCapabilities = output.recommendedFeatures.flatMap((feature) => {
    if (!feature || typeof feature !== "object" || Array.isArray(feature)) return [];
    const item = feature as Record<string, unknown>;
    return item.enabled === true && typeof item.key === "string" ? [item.key] : [];
  });
  const enabledSet = new Set(enabledCapabilities);
  const dropped: DroppedCustomField[] = [];
  const customFields = output.customFields.filter((field, index) => {
    if (!field || typeof field !== "object" || Array.isArray(field)) return true;
    const module = (field as Record<string, unknown>).module;
    if (
      typeof module === "string" && capabilities.includes(module) &&
      !enabledSet.has(module)
    ) {
      dropped.push({
        path: `customFields[${index}].module`,
        module,
        allowedEnabledCapabilities: enabledCapabilities,
        reason: "module_not_enabled",
      });
      return false;
    }
    return true;
  });
  return dropped.length === 0
    ? { value, dropped }
    : { value: { ...output, customFields }, dropped };
}

/**
 * Validates the application contract after a provider has returned valid JSON.
 * OpenAI strict schemas represent application-optional values as required,
 * nullable properties, so `null` remains valid for those two fields.
 */
export function validateBusinessConfigurationOutput(
  value: unknown,
  contract: BusinessConfigurationContract,
): BusinessConfigurationValidation {
  const typeOf = (item: unknown) => item === null
    ? "null"
    : Array.isArray(item)
    ? "array"
    : typeof item;
  const fail = (
    path: string,
    expected: string,
    actual: unknown,
    reason: string,
    details: Pick<ContractValidationIssue, "module" | "allowedEnabledCapabilities"> = {},
  ): BusinessConfigurationValidation => ({
    value: null,
    issue: { path, expected, actualType: typeOf(actual), reason, ...details },
  });
  const object = (item: unknown) =>
    item !== null && typeof item === "object" && !Array.isArray(item)
      ? item as Record<string, unknown>
      : null;
  const text = (item: unknown, maxLength: number) =>
    typeof item === "string" && item.trim().length > 0 &&
      item.length <= maxLength;
  const output = object(value);
  if (!output) return fail("$", "object", value, "not_an_object");

  if (!text(output.businessCategory, 60)) {
    return fail(
      "businessCategory",
      "non-empty string (max 60)",
      output.businessCategory,
      "invalid_text",
    );
  }
  if (!text(output.summary, 160)) {
    return fail(
      "summary",
      "non-empty string (max 160)",
      output.summary,
      "invalid_text",
    );
  }
  const features = output.recommendedFeatures;
  if (!Array.isArray(features) || features.length === 0 || features.length > 5) {
    return fail(
      "recommendedFeatures",
      "non-empty array (max 5)",
      features,
      "invalid_array",
    );
  }
  const customFields = output.customFields;
  if (!Array.isArray(customFields) || customFields.length > 4) {
    return fail("customFields", "array (max 4)", customFields, "invalid_array");
  }
  const workflow = output.workflow;
  if (!Array.isArray(workflow) || workflow.length > 4) {
    return fail("workflow", "array (max 4)", workflow, "invalid_array");
  }
  const widgets = output.dashboardWidgets;
  if (!Array.isArray(widgets) || widgets.length > 3) {
    return fail(
      "dashboardWidgets",
      "array (max 3)",
      widgets,
      "invalid_array",
    );
  }
  const unsupported = output.unsupportedRequirements;
  if (!Array.isArray(unsupported) || unsupported.length > 2) {
    return fail(
      "unsupportedRequirements",
      "array (max 2)",
      unsupported,
      "invalid_array",
    );
  }
  const paymentRules = object(output.paymentRules);
  if (!paymentRules) {
    return fail("paymentRules", "object", output.paymentRules, "invalid_object");
  }

  const recommendedFeatureKeys = new Set<string>();
  const enabledFeatureKeys = new Set<string>();
  for (const [index, feature] of features.entries()) {
    const item = object(feature);
    const prefix = `recommendedFeatures[${index}]`;
    if (!item) return fail(prefix, "object", feature, "invalid_object");
    if (typeof item.key !== "string" || !contract.capabilities.includes(item.key)) {
      return fail(`${prefix}.key`, "supported capability", item.key, "invalid_enum");
    }
    if (recommendedFeatureKeys.has(item.key)) {
      return fail(`${prefix}.key`, "unique capability", item.key, "duplicate_value");
    }
    if (!text(item.name, 14)) {
      return fail(`${prefix}.name`, "non-empty string (max 14)", item.name, "invalid_text");
    }
    if (typeof item.enabled !== "boolean") {
      return fail(`${prefix}.enabled`, "boolean", item.enabled, "invalid_type");
    }
    if (!text(item.reason, 120)) {
      return fail(`${prefix}.reason`, "non-empty string (max 120)", item.reason, "invalid_text");
    }
    if (!Array.isArray(item.actions) || item.actions.length === 0 || item.actions.length > 6) {
      return fail(`${prefix}.actions`, "non-empty array (max 6)", item.actions, "invalid_array");
    }
    for (const [actionIndex, action] of item.actions.entries()) {
      if (
        typeof action !== "string" ||
        !(contract.capabilityActions[item.key] ?? []).includes(action)
      ) {
        return fail(
          `${prefix}.actions[${actionIndex}]`,
          "action supported by capability",
          action,
          "invalid_action",
        );
      }
    }
    recommendedFeatureKeys.add(item.key);
    if (item.enabled) enabledFeatureKeys.add(item.key);
  }

  for (const [index, field] of customFields.entries()) {
    const item = object(field);
    const prefix = `customFields[${index}]`;
    if (!item) return fail(prefix, "object", field, "invalid_object");
    if (typeof item.module !== "string" || !enabledFeatureKeys.has(item.module)) {
      return fail(
        `${prefix}.module`,
        "enabled capability",
        item.module,
        "invalid_enum",
        {
          module: typeof item.module === "string" ? item.module : null,
          allowedEnabledCapabilities: [...enabledFeatureKeys],
        },
      );
    }
    if (!text(item.key, 30)) {
      return fail(`${prefix}.key`, "non-empty string (max 30)", item.key, "invalid_text");
    }
    if (!text(item.label, 40)) {
      return fail(`${prefix}.label`, "non-empty string (max 40)", item.label, "invalid_text");
    }
    if (typeof item.type !== "string" || !contract.fieldTypes.includes(item.type)) {
      return fail(`${prefix}.type`, "supported field type", item.type, "invalid_enum");
    }
    if (typeof item.required !== "boolean") {
      return fail(`${prefix}.required`, "boolean", item.required, "invalid_type");
    }
    // OpenAI strict output uses null for an app-optional array; Gemini may omit it.
    if (item.options !== undefined && item.options !== null) {
      if (!Array.isArray(item.options) || item.options.length > 6) {
        return fail(`${prefix}.options`, "array or null (max 6)", item.options, "invalid_array");
      }
      for (const [optionIndex, option] of item.options.entries()) {
        if (!text(option, 30)) {
          return fail(
            `${prefix}.options[${optionIndex}]`,
            "non-empty string (max 30)",
            option,
            "invalid_text",
          );
        }
      }
    }
  }

  for (const [index, step] of workflow.entries()) {
    const item = object(step);
    const prefix = `workflow[${index}]`;
    if (!item) return fail(prefix, "object", step, "invalid_object");
    if (!text(item.key, 30)) {
      return fail(`${prefix}.key`, "non-empty string (max 30)", item.key, "invalid_text");
    }
    if (!text(item.label, 60)) {
      return fail(`${prefix}.label`, "non-empty string (max 60)", item.label, "invalid_text");
    }
    if (!Number.isInteger(item.order) || Number(item.order) < 1) {
      return fail(`${prefix}.order`, "integer (minimum 1)", item.order, "invalid_number");
    }
  }

  for (const [index, widget] of widgets.entries()) {
    if (typeof widget !== "string" || !contract.dashboardWidgets.includes(widget)) {
      return fail(`dashboardWidgets[${index}]`, "supported widget", widget, "invalid_enum");
    }
  }
  for (const [index, requirement] of unsupported.entries()) {
    const item = object(requirement);
    const prefix = `unsupportedRequirements[${index}]`;
    if (!item) return fail(prefix, "object", requirement, "invalid_object");
    if (!text(item.name, 40)) {
      return fail(`${prefix}.name`, "non-empty string (max 40)", item.name, "invalid_text");
    }
    if (!text(item.reason, 120)) {
      return fail(`${prefix}.reason`, "non-empty string (max 120)", item.reason, "invalid_text");
    }
  }
  if (typeof paymentRules.supportsDownPayment !== "boolean") {
    return fail(
      "paymentRules.supportsDownPayment",
      "boolean",
      paymentRules.supportsDownPayment,
      "invalid_type",
    );
  }
  // OpenAI strict output uses null for this app-optional number; Gemini may omit it.
  const downPayment = paymentRules.suggestedDownPaymentPercent;
  if (
    downPayment !== undefined && downPayment !== null &&
    (!Number.isInteger(downPayment) || Number(downPayment) < 0 || Number(downPayment) > 100)
  ) {
    return fail(
      "paymentRules.suggestedDownPaymentPercent",
      "integer 0..100 or null",
      downPayment,
      "invalid_number",
    );
  }
  return { value: output, issue: null };
}

/**
 * Reads the REST Responses API shape deliberately: only `message` output
 * items may contain `output_text` content. `output_text` at the response root
 * is an SDK convenience property and is not relied on by this Edge Function.
 */
export function extractOpenAiStructuredOutput(
  payload: unknown,
): OpenAiStructuredOutput {
  if (!payload || typeof payload !== "object") {
    return {
      responseStatus: null,
      incompleteReason: null,
      outputItemTypes: [],
      contentItemTypes: [],
      text: null,
    };
  }
  const root = payload as Record<string, unknown>;
  const responseStatus = typeof root.status === "string" ? root.status : null;
  const incompleteDetails = root.incomplete_details;
  const incompleteReason = incompleteDetails &&
      typeof incompleteDetails === "object" &&
      typeof (incompleteDetails as Record<string, unknown>).reason === "string"
    ? (incompleteDetails as Record<string, unknown>).reason as string
    : null;
  const outputItemTypes: string[] = [];
  const contentItemTypes: string[] = [];
  const texts: string[] = [];
  if (Array.isArray(root.output)) {
    for (const item of root.output) {
      if (!item || typeof item !== "object") continue;
      const output = item as Record<string, unknown>;
      const itemType = typeof output.type === "string" ? output.type : "unknown";
      outputItemTypes.push(itemType);
      if (itemType !== "message" || !Array.isArray(output.content)) continue;
      for (const part of output.content) {
        if (!part || typeof part !== "object") continue;
        const content = part as Record<string, unknown>;
        const contentType = typeof content.type === "string"
          ? content.type
          : "unknown";
        contentItemTypes.push(contentType);
        if (contentType === "output_text" && typeof content.text === "string") {
          texts.push(content.text);
        }
      }
    }
  }
  return {
    responseStatus,
    incompleteReason,
    outputItemTypes,
    contentItemTypes,
    text: texts.length > 0 ? texts.join("\n") : null,
  };
}

function pause(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

/**
 * Centralizes cache creation and its safe non-cached fallback. The cache store
 * owns the cross-instance lease, so concurrent Edge Function invocations do
 * not all create the same provider cache.
 */
export class AiService {
  constructor(
    private readonly provider: AiProvider,
    private readonly cacheStore: PromptCacheStore,
  ) {}

  async generate(input: {
    settings: AiSettings;
    cacheKey: string;
    systemInstruction: string;
    dynamicPrompt: string;
    responseJsonSchema?: unknown;
    responseSchemaName?: string;
  }): Promise<AiGeneration> {
    const { settings } = input;
    if (!settings.promptCachingEnabled) {
      return {
        response: await this.generateWithoutCache(input),
        cacheUsed: false,
        cacheState: "disabled",
      };
    }

    const firstClaim = await this.waitForClaim(input.cacheKey);
    const cached = await this.generateFromClaim(firstClaim, input);
    if (cached) return cached;

    return {
      response: await this.generateWithoutCache(input),
      cacheUsed: false,
      cacheState: "fallback",
    };
  }

  private async waitForClaim(
    cacheKey: string,
    force = false,
  ): Promise<CacheClaim> {
    let claim = await this.cacheStore.claim(cacheKey, force);
    for (
      let attempt = 0;
      claim.state === "waiting" && attempt < cacheWaitAttempts;
      attempt++
    ) {
      await pause(cacheWaitMs);
      claim = await this.cacheStore.claim(cacheKey);
    }
    return claim;
  }

  private async generateFromClaim(
    claim: CacheClaim,
    input: {
      settings: AiSettings;
      cacheKey: string;
      systemInstruction: string;
      dynamicPrompt: string;
      responseJsonSchema?: unknown;
      responseSchemaName?: string;
    },
    didRetryInvalidCache = false,
  ): Promise<AiGeneration | null> {
    if (claim.state === "unavailable" || claim.state === "waiting") return null;

    if (claim.state === "creator") {
      let cache: PromptCache;
      try {
        cache = await this.provider.createCache({
          model: input.settings.model,
          cacheKey: input.cacheKey,
          systemInstruction: input.systemInstruction,
          ttlSeconds: input.settings.promptCacheTtlSeconds,
        });
        await this.cacheStore.saveReady({
          cacheKey: input.cacheKey,
          cacheName: cache.name,
          model: input.settings.model,
          expiresAt: cache.expiresAt,
        });
      } catch (_) {
        // Caching is an optimization; a provider cache failure must not block AI.
        await this.cacheStore.markUnavailable(input.cacheKey).catch(() =>
          undefined
        );
        return null;
      }
      const response = await this.generateWithCache(input, cache.name);
      if (this.isInvalidCacheResponse(response)) {
        await this.cacheStore.markUnavailable(input.cacheKey).catch(() =>
          undefined
        );
        return null;
      }
      return { response, cacheUsed: true, cacheState: "miss" };
    }

    const response = await this.generateWithCache(input, claim.cacheName);
    if (!this.isInvalidCacheResponse(response) || didRetryInvalidCache) {
      return { response, cacheUsed: true, cacheState: "hit" };
    }

    // A stale provider cache can outlive a database entry. One lease holder
    // recreates it; other callers use the normal request rather than retrying indefinitely.
    const retryClaim = await this.waitForClaim(input.cacheKey, true);
    return this.generateFromClaim(retryClaim, input, true);
  }

  private generateWithCache(
    input: {
      settings: AiSettings;
      systemInstruction: string;
      dynamicPrompt: string;
      responseJsonSchema?: unknown;
      responseSchemaName?: string;
    },
    cacheName: string,
  ) {
    return this.provider.generate({
      model: input.settings.model,
      systemInstruction: input.systemInstruction,
      dynamicPrompt: input.dynamicPrompt,
      responseJsonSchema: input.responseJsonSchema,
      responseSchemaName: input.responseSchemaName,
      cachedContent: cacheName,
      maxOutputTokens: input.settings.maxOutputTokens,
    });
  }

  private generateWithoutCache(input: {
    settings: AiSettings;
    systemInstruction: string;
    dynamicPrompt: string;
    responseJsonSchema?: unknown;
    responseSchemaName?: string;
  }) {
    return this.provider.generate({
      model: input.settings.model,
      systemInstruction: input.systemInstruction,
      dynamicPrompt: input.dynamicPrompt,
      responseJsonSchema: input.responseJsonSchema,
      responseSchemaName: input.responseSchemaName,
      maxOutputTokens: input.settings.maxOutputTokens,
    });
  }

  private isInvalidCacheResponse(response: Response) {
    return this.provider.isInvalidCacheResponse?.(response) ?? false;
  }
}
