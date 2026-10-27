-- 매장 지도 핀에 쓸 매장 사진 주소 컬럼을 추가한다 (비어 있으면 앱이 업종 아이콘을 쓴다)
-- 기존 공개 읽기 정책(stores_public_read)이 새 컬럼에도 그대로 적용된다. 권한 변경 없음.
alter table public.stores add column if not exists photo_url text;
