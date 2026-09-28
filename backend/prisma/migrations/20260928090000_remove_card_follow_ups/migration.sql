-- Bỏ thẻ ngữ cảnh (follow-up): thẻ con cũ thành thẻ thường — giữ nguyên id,
-- vị trí, ⭐/漢; chỉ mất liên kết về thẻ gốc.
ALTER TABLE "Card" DROP CONSTRAINT "Card_parentId_fkey";
ALTER TABLE "Card" DROP COLUMN "parentId";
