-- Provider/model dipisahkan supaya perpindahan dari Gemini ke OpenAI tidak
-- membutuhkan perubahan aplikasi Flutter ataupun membuka kunci API ke klien.
alter table public.ai_system_config
  add column if not exists provider text not null default 'gemini'
  check (provider in ('gemini', 'openai'));

-- Konfigurasi business builder hanya membutuhkan JSON ringkas. Batas ini
-- menghindari generasi panjang yang tidak digunakan UI dan menghemat kredit.
alter table public.ai_system_config
  alter column max_output_tokens set default 450;

update public.ai_system_config
set max_output_tokens = least(max_output_tokens, 450),
    daily_ai_limit = least(daily_ai_limit, 8),
    ai_rate_limit_per_minute = least(ai_rate_limit_per_minute, 3)
where id = true;
