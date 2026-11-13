-- Comité d’Éthique — schéma Supabase
-- À exécuter une seule fois dans Supabase : SQL Editor > New query.

create extension if not exists pgcrypto;

create table public.suggestions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  author text check (author is null or char_length(author) <= 80),
  article text not null check (char_length(article) <= 120),
  body text not null check (char_length(body) between 10 and 2000),
  status text not null default 'Nouvelle'
    check (status in ('Nouvelle','En étude','Retenue','Acceptée','Rejetée')),
  motif text check (motif is null or char_length(motif) <= 1000)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  category text not null check (char_length(category) <= 60),
  body text not null check (char_length(body) between 10 and 4000),
  contact text check (contact is null or char_length(contact) <= 120),
  status text not null default 'Nouveau' check (status in ('Nouveau','En cours','Clos'))
);

create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

alter table public.suggestions enable row level security;
alter table public.reports enable row level security;
alter table public.admins enable row level security;
-- admins : aucune politique, la table n’est lisible par personne via l’API.

-- Envoi public (visiteurs non connectés)
create policy "envoi suggestion" on public.suggestions
  for insert to anon, authenticated
  with check (status = 'Nouvelle' and motif is null);

create policy "envoi signalement" on public.reports
  for insert to anon, authenticated
  with check (status = 'Nouveau');

-- Lecture, modification et suppression réservées aux administrateurs
create policy "admin suggestions" on public.suggestions
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "admin signalements" on public.reports
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Registre public : uniquement les suggestions déjà examinées, sans le nom de l’auteur
create view public.public_decisions as
  select id, created_at, article, body, status, motif
  from public.suggestions
  where status <> 'Nouvelle';

grant select on public.public_decisions to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- Après avoir créé votre compte dans Authentication > Users, déclarez-le administrateur
-- (remplacez l’adresse) :
-- insert into public.admins (user_id) select id from auth.users where email = 'vous@exemple.fr';
