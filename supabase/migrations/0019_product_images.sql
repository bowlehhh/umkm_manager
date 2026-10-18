-- Foto produk disimpan terpisah di Storage agar ukuran tabel produk tetap kecil.
alter table public.products
  add column if not exists image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do nothing;

-- Struktur objek: {business_id}/{timestamp}.jpg. Hanya anggota bisnis yang
-- dapat mengunggah foto ke folder bisnisnya sendiri.
create policy "business members upload product images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'product-images'
  and public.is_business_member((storage.foldername(name))[1]::uuid)
);

create policy "business members delete product images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'product-images'
  and public.is_business_member((storage.foldername(name))[1]::uuid)
);
