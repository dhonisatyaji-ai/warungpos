-- WarungPOS · Supabase (PostgreSQL)
-- Jalankan seluruh file ini di: Supabase → SQL Editor → New query → Run
-- Zona waktu toko
create extension if not exists pgcrypto;

create or replace function gen_id(prefix text)
returns text
language sql
as $$
  select prefix
    || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS')
    || lpad((floor(random()*900)+100)::int::text, 3, '0');
$$;

create or replace function now_jkt()
returns timestamp
language sql
stable
as $$
  select (now() at time zone 'Asia/Jakarta');
$$;

create table if not exists pengaturan (
  kunci text primary key,
  nilai text
);

create table if not exists users (
  id text primary key default gen_id('U'),
  username text unique not null,
  password_hash text not null,
  nama text not null,
  role text not null default 'kasir' check (role in ('admin','kasir')),
  aktif boolean not null default true,
  created_at timestamp not null default now_jkt()
);

create table if not exists kategori (
  id text primary key default gen_id('K'),
  nama text not null,
  warna text default '#0ea5e9',
  aktif boolean not null default true
);

create table if not exists jenis (
  id text primary key default gen_id('J'),
  nama text not null,
  kode text not null,
  deskripsi text,
  aktif boolean not null default true
);

create table if not exists supplier (
  id text primary key default gen_id('S'),
  nama text not null,
  telp text,
  alamat text,
  aktif boolean not null default true
);

create table if not exists pelanggan (
  id text primary key default gen_id('P'),
  nama text not null,
  telp text,
  alamat text,
  saldo_hutang numeric(18,2) not null default 0,
  aktif boolean not null default true,
  created_at timestamp not null default now_jkt()
);

create table if not exists produk (
  id text primary key default gen_id('PR'),
  sku text,
  barcode text,
  nama text not null,
  kategori_id text references kategori(id),
  jenis_id text references jenis(id),
  supplier_id text references supplier(id),
  satuan text not null default 'pcs',
  harga_beli numeric(18,2) not null default 0,
  harga_jual numeric(18,2) not null default 0,
  harga_dingin numeric(18,2) not null default 0,
  stok numeric(18,4) not null default 0,
  stok_min numeric(18,4) not null default 0,
  aktif boolean not null default true,
  created_at timestamp not null default now_jkt(),
  updated_at timestamp not null default now_jkt()
);

create table if not exists penjualan (
  id text primary key default gen_id('PJ'),
  nomor text unique not null,
  tanggal timestamp not null default now_jkt(),
  pelanggan_id text references pelanggan(id),
  user_id text,
  subtotal numeric(18,2) not null default 0,
  diskon numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  bayar numeric(18,2) not null default 0,
  kembalian numeric(18,2) not null default 0,
  metode text not null default 'tunai',
  status text not null default 'selesai',
  catatan text
);

create table if not exists penjualan_item (
  id text primary key default gen_id('PI'),
  penjualan_id text not null references penjualan(id) on delete cascade,
  produk_id text references produk(id),
  nama_produk text,
  qty numeric(18,4) not null,
  satuan text,
  harga_satuan numeric(18,2) not null,
  is_dingin int not null default 0,
  mode_berat text,
  nominal numeric(18,2) not null default 0,
  subtotal numeric(18,2) not null
);

create table if not exists pembelian (
  id text primary key default gen_id('PB'),
  nomor text unique not null,
  tanggal timestamp not null default now_jkt(),
  supplier_id text references supplier(id),
  user_id text,
  total numeric(18,2) not null default 0,
  status text not null default 'selesai',
  catatan text
);

create table if not exists pembelian_item (
  id text primary key default gen_id('BI'),
  pembelian_id text not null references pembelian(id) on delete cascade,
  produk_id text references produk(id),
  nama_produk text,
  qty numeric(18,4) not null,
  harga_beli numeric(18,2) not null,
  subtotal numeric(18,2) not null
);

create table if not exists retur_penjualan (
  id text primary key default gen_id('RJ'),
  nomor text unique not null,
  penjualan_id text references penjualan(id),
  tanggal timestamp not null default now_jkt(),
  user_id text,
  total numeric(18,2) not null default 0,
  alasan text,
  metode_refund text
);

create table if not exists retur_penjualan_item (
  id text primary key default gen_id('RI'),
  retur_id text not null references retur_penjualan(id) on delete cascade,
  produk_id text,
  nama_produk text,
  qty numeric(18,4) not null,
  harga numeric(18,2) not null,
  subtotal numeric(18,2) not null
);

create table if not exists retur_pembelian (
  id text primary key default gen_id('RB'),
  nomor text unique not null,
  pembelian_id text references pembelian(id),
  tanggal timestamp not null default now_jkt(),
  user_id text,
  total numeric(18,2) not null default 0,
  alasan text
);

create table if not exists retur_pembelian_item (
  id text primary key default gen_id('RBI'),
  retur_id text not null references retur_pembelian(id) on delete cascade,
  produk_id text,
  nama_produk text,
  qty numeric(18,4) not null,
  harga numeric(18,2) not null,
  subtotal numeric(18,2) not null
);

create table if not exists hutang (
  id text primary key default gen_id('HT'),
  pelanggan_id text not null references pelanggan(id),
  tanggal timestamp not null default now_jkt(),
  jenis text not null check (jenis in ('hutang','cicilan')),
  referensi text,
  jumlah numeric(18,2) not null,
  saldo_sebelum numeric(18,2) not null,
  saldo_sesudah numeric(18,2) not null,
  keterangan text,
  user_id text
);

create table if not exists audit_log (
  id text primary key default gen_id('LG'),
  waktu timestamp not null default now_jkt(),
  user_id text,
  aksi text,
  detail text
);

create table if not exists kas (
  id text primary key default gen_id('KS'),
  tanggal timestamp not null default now_jkt(),
  jenis text not null check (jenis in ('masuk','keluar')),
  jumlah numeric(18,2) not null,
  keterangan text,
  referensi text,
  user_id text
);

create table if not exists tutup_kasir (
  id text primary key default gen_id('TK'),
  tanggal date not null,
  modal_awal numeric(18,2) not null default 0,
  omset numeric(18,2) not null default 0,
  pengeluaran numeric(18,2) not null default 0,
  modal_besok numeric(18,2) not null default 0,
  setoran numeric(18,2) not null default 0,
  rincian jsonb not null default '{}'::jsonb,
  catatan text,
  user_id text not null default '',
  created_at timestamp not null default now_jkt(),
  unique (tanggal, user_id)
);

create table if not exists opname (
  id text primary key default gen_id('OP'),
  nomor text unique not null,
  tanggal timestamp not null default now_jkt(),
  user_id text,
  catatan text,
  jumlah_item int not null default 0
);

create table if not exists opname_item (
  id text primary key default gen_id('OI'),
  opname_id text not null references opname(id) on delete cascade,
  produk_id text references produk(id),
  nama_produk text,
  stok_sistem numeric(18,4) not null default 0,
  stok_fisik numeric(18,4) not null default 0,
  selisih numeric(18,4) not null default 0,
  satuan text
);

create index if not exists idx_produk_nama on produk (nama);
create index if not exists idx_pj_tgl on penjualan (tanggal desc);
create index if not exists idx_pi_pj on penjualan_item (penjualan_id);
create index if not exists idx_ht_pl on hutang (pelanggan_id, tanggal);

-- ========== RLS: anon boleh (kunci ada di frontend, sama model Web App Anyone) ==========
do $$
declare t text;
begin
  foreach t in array array[
    'pengaturan','users','kategori','jenis','supplier','pelanggan','produk',
    'penjualan','penjualan_item','pembelian','pembelian_item',
    'retur_penjualan','retur_penjualan_item','retur_pembelian','retur_pembelian_item',
    'hutang','audit_log','kas','tutup_kasir','opname','opname_item'
  ]
  loop
    if to_regclass('public.' || t) is null then continue; end if;
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists anon_all on %I', t);
    execute format('create policy anon_all on %I for all to anon using (true) with check (true)', t);
    execute format('grant select, insert, update, delete on table %I to anon, authenticated', t);
  end loop;
end $$;

grant usage on schema public to anon, authenticated;

-- ========== UTIL ==========
create or replace function convert_to_base(qty numeric, from_u text, base_u text)
returns numeric language plpgsql immutable as $$
declare f text := lower(coalesce(from_u, base_u, ''));
        b text := lower(coalesce(base_u, ''));
begin
  if f = b then return qty; end if;
  if b = 'kg' and f in ('gram','g','gr') then return qty / 1000; end if;
  if b = 'gram' and f = 'kg' then return qty * 1000; end if;
  if b in ('liter','l') and f = 'ml' then return qty / 1000; end if;
  if b = 'ml' and f in ('liter','l') then return qty * 1000; end if;
  return qty;
end $$;

create or replace function catat_hutang(
  p_pelanggan_id text, p_jenis text, p_ref text, p_jumlah numeric, p_ket text, p_user text
) returns numeric language plpgsql as $$
declare sebelum numeric; sesudah numeric;
begin
  select saldo_hutang into sebelum from pelanggan where id = p_pelanggan_id for update;
  if not found then raise exception 'Pelanggan tidak ditemukan'; end if;
  if p_jenis = 'hutang' then sesudah := round(sebelum + p_jumlah, 2);
  else sesudah := round(greatest(0, sebelum - p_jumlah), 2);
  end if;
  insert into hutang(pelanggan_id, jenis, referensi, jumlah, saldo_sebelum, saldo_sesudah, keterangan, user_id)
  values (p_pelanggan_id, p_jenis, coalesce(p_ref,''), p_jumlah, sebelum, sesudah, coalesce(p_ket,''), p_user);
  update pelanggan set saldo_hutang = sesudah where id = p_pelanggan_id;
  return sesudah;
end $$;

-- ========== RPC ==========
create or replace function fn_ping()
returns json language sql stable as $$
  select json_build_object('pong', true, 'waktu', to_char(now_jkt(), 'YYYY-MM-DD"T"HH24:MI:SS'));
$$;

create or replace function fn_login(p_username text, p_password text)
returns json language plpgsql security definer as $$
declare u users%rowtype;
begin
  select * into u from users
   where lower(username) = lower(trim(p_username)) and aktif = true;
  if not found then raise exception 'User tidak ditemukan atau nonaktif'; end if;
  if u.password_hash is distinct from crypt(p_password, u.password_hash) then
    raise exception 'Password salah';
  end if;
  insert into audit_log(user_id, aksi, detail) values (u.id, 'login', u.username);
  return json_build_object(
    'id', u.id, 'username', u.username, 'nama', u.nama, 'role', u.role,
    'token', encode(digest(u.id || clock_timestamp()::text, 'sha256'), 'hex')
  );
end $$;

create or replace function fn_save_user(p json)
returns json language plpgsql security definer as $$
declare vid text := nullif(p->>'id','');
        vpass text := nullif(p->>'password','');
        row users;
begin
  if coalesce(p->>'username','') = '' or coalesce(p->>'nama','') = '' then
    raise exception 'Username dan nama wajib';
  end if;
  if exists (
    select 1 from users
     where lower(username)=lower(p->>'username') and id is distinct from vid
  ) then raise exception 'Username sudah dipakai'; end if;

  if vid is null then
    if vpass is null then raise exception 'Password wajib untuk user baru'; end if;
    insert into users(username, password_hash, nama, role, aktif)
    values (p->>'username', crypt(vpass, gen_salt('bf')), p->>'nama', coalesce(p->>'role','kasir'), true)
    returning * into row;
  else
    update users set
      username = p->>'username',
      nama = p->>'nama',
      role = coalesce(p->>'role', role),
      password_hash = case when vpass is not null then crypt(vpass, gen_salt('bf')) else password_hash end,
      aktif = coalesce((p->>'aktif')::boolean, aktif)
    where id = vid
    returning * into row;
  end if;
  return json_build_object('id', row.id, 'username', row.username, 'nama', row.nama, 'role', row.role, 'aktif', row.aktif);
end $$;

create or replace function fn_dashboard()
returns json language plpgsql stable as $$
declare d date := (now_jkt())::date;
begin
  return json_build_object(
    'tanggal', d,
    'transaksi_hari_ini', (select count(*) from penjualan where tanggal::date = d and status <> 'batal'),
    'omzet_hari_ini', coalesce((select sum(total) from penjualan where tanggal::date = d and status <> 'batal'),0),
    'tunai_hari_ini', coalesce((select sum(total) from penjualan where tanggal::date = d and metode='tunai'),0),
    'hutang_hari_ini', coalesce((select sum(case when metode='hutang' then total else total-bayar end)
        from penjualan where tanggal::date = d and metode in ('hutang','campuran')),0),
    'total_produk', (select count(*) from produk where aktif),
    'stok_menipis', (select count(*) from produk where aktif and stok <= stok_min),
    'total_piutang', coalesce((select sum(saldo_hutang) from pelanggan),0)
  );
end $$;

create or replace function fn_penjualan(p json)
returns json language plpgsql as $$
declare
  items json := p->'items';
  metode text := lower(coalesce(p->>'metode','tunai'));
  plid text := coalesce(nullif(p->>'pelanggan_id',''),'P0');
  it json; pr produk%rowtype; jen jenis%rowtype;
  is_dingin boolean; harga numeric; qty numeric; mode_berat text; nominal numeric; line numeric;
  subtotal numeric := 0; diskon numeric := coalesce((p->>'diskon')::numeric,0);
  total numeric; bayar numeric := coalesce((p->>'bayar')::numeric,0); kembalian numeric := 0;
  vid text; vnomor text; vt timestamp := now_jkt();
  hutang_nom numeric := 0;
  out_items jsonb := '[]'::jsonb;
begin
  if items is null or json_array_length(items) = 0 then raise exception 'Keranjang kosong'; end if;
  if metode = 'hutang' and (plid is null or plid = 'P0') then
    raise exception 'Pelanggan wajib dipilih untuk transaksi hutang';
  end if;

  for it in select * from json_array_elements(items)
  loop
    select * into pr from produk where id = it->>'produk_id' and aktif for update;
    if not found then raise exception 'Produk tidak valid'; end if;
    select * into jen from jenis where id = pr.jenis_id;
    is_dingin := coalesce((it->>'is_dingin')::int,0)=1 and lower(coalesce(jen.kode,''))='minuman';
    harga := case when is_dingin then coalesce(nullif(pr.harga_dingin,0), pr.harga_jual) else pr.harga_jual end;
    qty := coalesce((it->>'qty')::numeric,0);
    mode_berat := '';
    nominal := 0;
    if lower(coalesce(jen.kode,'')) = 'berat' then
      mode_berat := coalesce(nullif(it->>'mode_berat',''),'berat');
      if mode_berat = 'nominal' then
        nominal := coalesce((it->>'nominal')::numeric,0);
        if nominal <= 0 then raise exception 'Nominal % tidak valid', pr.nama; end if;
        if harga <= 0 then raise exception 'Harga % belum diisi', pr.nama; end if;
        qty := round(nominal / harga, 4);
      else
        qty := convert_to_base(coalesce((it->>'qty')::numeric,0), coalesce(it->>'satuan_input', pr.satuan), pr.satuan);
      end if;
    end if;
    if qty <= 0 then raise exception 'Qty % tidak valid', pr.nama; end if;
    if pr.stok + 0.0000001 < qty then
      raise exception 'Stok % tidak cukup (sisa % %)', pr.nama, pr.stok, pr.satuan;
    end if;
    line := round(case when lower(coalesce(jen.kode,''))='berat' and mode_berat='nominal' then nominal else qty * harga end, 2);
    subtotal := subtotal + line;
    update produk set stok = round(stok - qty, 4), updated_at = now_jkt() where id = pr.id;
    out_items := out_items || jsonb_build_array(jsonb_build_object(
      'produk_id', pr.id, 'nama_produk', pr.nama, 'qty', qty, 'satuan', pr.satuan,
      'harga_satuan', harga, 'is_dingin', case when is_dingin then 1 else 0 end,
      'mode_berat', mode_berat, 'nominal', nominal, 'subtotal', line
    ));
  end loop;

  total := round(greatest(0, subtotal - diskon), 2);
  if metode = 'hutang' then bayar := 0; kembalian := 0;
  elsif metode = 'campuran' then
    if bayar > total then raise exception 'Bayar campuran tidak boleh lebih dari total'; end if;
    kembalian := 0;
  elsif metode in ('qris','transfer','debit') then
    bayar := total;
    kembalian := 0;
  else
    if bayar < total then raise exception 'Uang bayar kurang'; end if;
    kembalian := round(bayar - total, 2);
  end if;

  vid := gen_id('PJ');
  vnomor := 'PJ-' || to_char(vt, 'YYYYMMDD-HH24MISS');
  insert into penjualan(id, nomor, tanggal, pelanggan_id, user_id, subtotal, diskon, total, bayar, kembalian, metode, status, catatan)
  values (vid, vnomor, vt, plid, p->>'user_id', subtotal, diskon, total, bayar, kembalian, metode, 'selesai', coalesce(p->>'catatan',''));

  insert into penjualan_item(penjualan_id, produk_id, nama_produk, qty, satuan, harga_satuan, is_dingin, mode_berat, nominal, subtotal)
  select vid, x->>'produk_id', x->>'nama_produk', (x->>'qty')::numeric, x->>'satuan',
         (x->>'harga_satuan')::numeric, (x->>'is_dingin')::int, x->>'mode_berat',
         (x->>'nominal')::numeric, (x->>'subtotal')::numeric
  from jsonb_array_elements(out_items) e(x);

  hutang_nom := case when metode='hutang' then total when metode='campuran' then round(total-bayar,2) else 0 end;
  if hutang_nom > 0 then
    perform catat_hutang(plid, 'hutang', vid, hutang_nom, 'Belanja '||vnomor, p->>'user_id');
  end if;
  insert into audit_log(user_id, aksi, detail) values (p->>'user_id', 'penjualan', vnomor);

  return json_build_object(
    'id', vid, 'nomor', vnomor, 'tanggal', to_char(vt, 'YYYY-MM-DD"T"HH24:MI:SS'),
    'subtotal', subtotal, 'diskon', diskon, 'total', total, 'bayar', bayar, 'kembalian', kembalian,
    'metode', metode, 'pelanggan_id', plid, 'items', out_items::json
  );
end $$;

create or replace function fn_pembelian(p json)
returns json language plpgsql as $$
declare items json := p->'items'; it json; pr produk%rowtype;
        qty numeric; hb numeric; sub numeric; total numeric := 0;
        vid text; vnomor text;
begin
  if items is null or json_array_length(items)=0 then raise exception 'Item pembelian kosong'; end if;
  if coalesce(p->>'supplier_id','') = '' then raise exception 'Supplier wajib dipilih'; end if;
  vid := gen_id('PB'); vnomor := 'PB-' || to_char(now_jkt(), 'YYYYMMDD-HH24MISS');
  insert into pembelian(id, nomor, tanggal, supplier_id, user_id, total, status, catatan)
  values (vid, vnomor, now_jkt(), p->>'supplier_id', p->>'user_id', 0, 'selesai', coalesce(p->>'catatan',''));
  for it in select * from json_array_elements(items)
  loop
    select * into pr from produk where id = it->>'produk_id' for update;
    if not found then raise exception 'Produk tidak ditemukan'; end if;
    qty := coalesce((it->>'qty')::numeric,0);
    hb := coalesce(nullif(it->>'harga_beli','')::numeric, pr.harga_beli);
    if qty <= 0 then raise exception 'Qty tidak valid'; end if;
    sub := round(qty * hb, 2); total := total + sub;
    insert into pembelian_item(pembelian_id, produk_id, nama_produk, qty, harga_beli, subtotal)
    values (vid, pr.id, pr.nama, qty, hb, sub);
    update produk set stok = round(stok + qty, 4), harga_beli = hb, updated_at = now_jkt() where id = pr.id;
  end loop;
  update pembelian set total = total where id = vid;
  return json_build_object('id', vid, 'nomor', vnomor, 'total', total);
end $$;

create or replace function fn_retur_jual(p json)
returns json language plpgsql as $$
declare pj penjualan%rowtype; items json := p->'items'; it json; line penjualan_item%rowtype;
        qty numeric; sub numeric; total numeric := 0; vid text; vnomor text; metode text;
begin
  select * into pj from penjualan where id = p->>'penjualan_id';
  if not found then raise exception 'Transaksi penjualan tidak ditemukan'; end if;
  if items is null or json_array_length(items)=0 then raise exception 'Item retur kosong'; end if;
  vid := gen_id('RJ'); vnomor := 'RJ-' || to_char(now_jkt(), 'YYYYMMDD-HH24MISS');
  metode := coalesce(p->>'metode_refund','tunai');
  insert into retur_penjualan(id, nomor, penjualan_id, tanggal, user_id, total, alasan, metode_refund)
  values (vid, vnomor, pj.id, now_jkt(), p->>'user_id', 0, coalesce(p->>'alasan',''), metode);
  for it in select * from json_array_elements(items)
  loop
    select * into line from penjualan_item where penjualan_id = pj.id and produk_id = it->>'produk_id' limit 1;
    if not found then raise exception 'Produk tidak ada di transaksi asal'; end if;
    qty := coalesce((it->>'qty')::numeric,0);
    if qty <= 0 or qty > line.qty + 0.0000001 then raise exception 'Qty retur tidak valid'; end if;
    sub := round(qty * line.harga_satuan, 2); total := total + sub;
    insert into retur_penjualan_item(retur_id, produk_id, nama_produk, qty, harga, subtotal)
    values (vid, line.produk_id, line.nama_produk, qty, line.harga_satuan, sub);
    update produk set stok = round(stok + qty, 4), updated_at = now_jkt() where id = line.produk_id;
  end loop;
  update retur_penjualan set total = total where id = vid;
  if metode = 'potong_hutang' and pj.pelanggan_id is not null and pj.pelanggan_id <> 'P0' then
    perform catat_hutang(pj.pelanggan_id, 'cicilan', vid, total, 'Potong hutang retur '||vnomor, p->>'user_id');
  end if;
  return json_build_object('id', vid, 'nomor', vnomor, 'total', total);
end $$;

create or replace function fn_retur_beli(p json)
returns json language plpgsql as $$
declare pb pembelian%rowtype; items json := p->'items'; it json; line pembelian_item%rowtype;
        pr produk%rowtype; qty numeric; sub numeric; total numeric := 0; vid text; vnomor text;
begin
  select * into pb from pembelian where id = p->>'pembelian_id';
  if not found then raise exception 'Pembelian tidak ditemukan'; end if;
  if items is null or json_array_length(items)=0 then raise exception 'Item retur kosong'; end if;
  vid := gen_id('RB'); vnomor := 'RB-' || to_char(now_jkt(), 'YYYYMMDD-HH24MISS');
  insert into retur_pembelian(id, nomor, pembelian_id, tanggal, user_id, total, alasan)
  values (vid, vnomor, pb.id, now_jkt(), p->>'user_id', 0, coalesce(p->>'alasan',''));
  for it in select * from json_array_elements(items)
  loop
    select * into line from pembelian_item where pembelian_id = pb.id and produk_id = it->>'produk_id' limit 1;
    if not found then raise exception 'Produk tidak ada di pembelian asal'; end if;
    qty := coalesce((it->>'qty')::numeric,0);
    select * into pr from produk where id = it->>'produk_id' for update;
    if qty <= 0 then raise exception 'Qty tidak valid'; end if;
    if pr.stok + 0.0000001 < qty then raise exception 'Stok tidak cukup untuk diretur'; end if;
    sub := round(qty * line.harga_beli, 2); total := total + sub;
    insert into retur_pembelian_item(retur_id, produk_id, nama_produk, qty, harga, subtotal)
    values (vid, line.produk_id, line.nama_produk, qty, line.harga_beli, sub);
    update produk set stok = round(stok - qty, 4), updated_at = now_jkt() where id = pr.id;
  end loop;
  insert into retur_pembelian(id, nomor, pembelian_id, tanggal, user_id, total, alasan)
  values (vid, vnomor, pb.id, now_jkt(), p->>'user_id', total, coalesce(p->>'alasan',''));
  return json_build_object('id', vid, 'nomor', vnomor, 'total', total);
end $$;

create or replace function fn_bayar_hutang(p json)
returns json language plpgsql as $$
declare pl pelanggan%rowtype; j numeric := coalesce((p->>'jumlah')::numeric,0); sisa numeric;
begin
  select * into pl from pelanggan where id = p->>'pelanggan_id' for update;
  if not found then raise exception 'Pelanggan tidak ditemukan'; end if;
  if j <= 0 then raise exception 'Nominal cicilan tidak valid'; end if;
  if j > pl.saldo_hutang + 0.009 then raise exception 'Cicilan melebihi sisa hutang'; end if;
  sisa := catat_hutang(pl.id, 'cicilan', coalesce(p->>'referensi',''), j, coalesce(p->>'keterangan','Cicilan hutang'), p->>'user_id');
  return json_build_object('saldo_hutang', sisa, 'dibayar', j);
end $$;

create or replace function fn_adjust_stok(p json)
returns json language plpgsql as $$
declare pr produk%rowtype; nexts numeric;
begin
  select * into pr from produk where id = coalesce(p->>'produk_id', p->>'id') for update;
  if not found then raise exception 'Produk tidak ditemukan'; end if;
  nexts := round(pr.stok + coalesce((p->>'delta')::numeric,0), 4);
  if nexts < 0 then raise exception 'Stok tidak cukup'; end if;
  update produk set stok = nexts, updated_at = now_jkt() where id = pr.id;
  return json_build_object('id', pr.id, 'stok', nexts, 'nama', pr.nama);
end $$;

create or replace function fn_save_pengaturan(p json)
returns json language plpgsql as $$
declare r record;
begin
  for r in select * from json_each_text(p)
  loop
    if r.key in ('action','payload','user_id','password') then continue; end if;
    insert into pengaturan(kunci, nilai) values (r.key, r.value)
    on conflict (kunci) do update set nilai = excluded.nilai;
  end loop;
  return (select coalesce(json_object_agg(kunci, nilai), '{}'::json) from pengaturan);
end $$;

create or replace function fn_opname(p json)
returns json language plpgsql as $$
declare items json := p->'items'; it json; pr produk%rowtype;
        fisik numeric; sist numeric; nitem int := 0;
        vid text; vnomor text; vtgl timestamp;
        raw_tgl text;
begin
  if items is null or json_array_length(items)=0 then
    raise exception 'Isi stok fisik minimal satu produk';
  end if;
  vid := gen_id('OP');
  vnomor := 'OP-' || to_char(now_jkt(), 'YYYYMMDD-HH24MISS');
  raw_tgl := nullif(trim(coalesce(p->>'tanggal','')), '');
  if raw_tgl is null then
    vtgl := now_jkt();
  else
    begin
      vtgl := raw_tgl::timestamp;
    exception when others then
      vtgl := now_jkt();
    end;
  end if;
  insert into opname(id, nomor, tanggal, user_id, catatan, jumlah_item)
  values (vid, vnomor, vtgl, p->>'user_id', coalesce(p->>'catatan',''), 0);
  for it in select * from json_array_elements(items)
  loop
    if coalesce(trim(it->>'stok_fisik'), '') = '' then continue; end if;
    select * into pr from produk where id = it->>'produk_id' for update;
    if not found then raise exception 'Produk tidak ditemukan'; end if;
    fisik := coalesce((it->>'stok_fisik')::numeric, 0);
    if fisik < 0 then raise exception 'Stok fisik tidak boleh minus'; end if;
    sist := pr.stok;
    insert into opname_item(opname_id, produk_id, nama_produk, stok_sistem, stok_fisik, selisih, satuan)
    values (vid, pr.id, pr.nama, sist, fisik, round(fisik - sist, 4), pr.satuan);
    update produk set stok = round(fisik, 4), updated_at = now_jkt() where id = pr.id;
    nitem := nitem + 1;
  end loop;
  if nitem = 0 then raise exception 'Isi stok fisik minimal satu produk'; end if;
  update opname set jumlah_item = nitem where id = vid;
  return json_build_object('id', vid, 'nomor', vnomor, 'jumlah_item', nitem);
end $$;

grant execute on all functions in schema public to anon, authenticated;

-- ========== SEED (hanya jika masih kosong) ==========
insert into pengaturan(kunci, nilai) values
  ('toko_nama','Warung POS'),
  ('toko_alamat','Jl. Malioboro No. 1, Yogyakarta'),
  ('toko_telp','0812-3456-7890'),
  ('toko_footer','Terima kasih sudah belanja.')
on conflict (kunci) do nothing;

insert into users(id, username, password_hash, nama, role, aktif) values
  ('U1','admin', crypt('admin123', gen_salt('bf')), 'Administrator','admin', true),
  ('U2','kasir', crypt('kasir123', gen_salt('bf')), 'Kasir Toko','kasir', true)
on conflict (id) do nothing;

insert into kategori(id, nama, warna) values
  ('K1','Minuman','#0ea5e9'),('K2','Sembako','#f59e0b'),('K3','Rokok','#64748b'),
  ('K4','Snack','#ec4899'),('K5','Sayur & Bumbu','#22c55e')
on conflict (id) do nothing;

insert into jenis(id, nama, kode, deskripsi) values
  ('J1','Satuan','satuan','Harga per pcs/bungkus/pak'),
  ('J2','Minuman','minuman','Dua harga: biasa dan dingin'),
  ('J3','Berat','berat','Beli per berat atau per nominal')
on conflict (id) do nothing;

insert into supplier(id, nama, telp, alamat) values
  ('S1','CV Sumber Rejeki','08111111111','Yogyakarta'),
  ('S2','PT Indogrosir','08222222222','Sleman')
on conflict (id) do nothing;

insert into pelanggan(id, nama, telp, alamat, saldo_hutang) values
  ('P0','Umum','-','-',0),
  ('P1','Heri','081234567890','Depok, Sleman',0),
  ('P2','Siti Aminah','082198765432','Kota Yogyakarta',0)
on conflict (id) do nothing;

insert into produk(id, sku, barcode, nama, kategori_id, jenis_id, supplier_id, satuan, harga_beli, harga_jual, harga_dingin, stok, stok_min) values
  ('PR1','MNM-001','8999999001','Golda Coffee','K1','J2','S1','pcs',2800,3500,4000,48,10),
  ('PR2','MNM-002','8999999002','Teh Pucuk Harum','K1','J2','S1','pcs',3200,4000,4500,36,10),
  ('PR3','MNM-003','8999999003','Aqua 600ml','K1','J2','S2','pcs',2500,3000,3500,60,12),
  ('PR4','SMB-001','8999999004','Bawang Merah','K5','J3','S1','kg',32000,40000,0,12.5,2),
  ('PR5','SMB-002','8999999005','Beras Premium','K2','J3','S2','kg',12000,14000,0,50,10),
  ('PR6','SMB-003','8999999006','Minyak Goreng','K2','J3','S2','liter',15000,18000,0,20,5),
  ('PR7','SMB-004','8999999007','Gula Pasir','K2','J3','S1','kg',14000,16000,0,25,5),
  ('PR8','RKK-001','8999999008','Rokok Sampoerna Mild','K3','J1','S2','pcs',22000,25000,0,40,8),
  ('PR9','RKK-002','8999999009','Rokok Magnum Filter','K3','J1','S2','pcs',18000,20000,0,30,8),
  ('PR10','SNK-001','8999999010','Indomie Goreng','K4','J1','S1','pcs',2800,3500,0,80,20)
on conflict (id) do nothing;
