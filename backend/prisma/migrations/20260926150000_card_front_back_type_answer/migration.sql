-- kr/vi -> back/front: đổi tên cột (không drop/add) để giữ nguyên dữ liệu.
ALTER TABLE "Card" RENAME COLUMN "kr" TO "back";
ALTER TABLE "Card" RENAME COLUMN "vi" TO "front";

-- Thẻ mới mặc định là thẻ tự chấm (lật thẻ).
ALTER TABLE "Card" ADD COLUMN "typeAnswer" BOOLEAN NOT NULL DEFAULT false;

-- Thẻ đã có: áp cùng quy tắc với lúc nhập bộ — mặt sau ≤ 3 từ thì gõ đáp án.
UPDATE "Card"
SET "typeAnswer" = true
WHERE cardinality(regexp_split_to_array(btrim("back"), '\s+')) <= 3;
