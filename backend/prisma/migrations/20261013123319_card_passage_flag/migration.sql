-- AlterTable
ALTER TABLE "Card" ADD COLUMN     "passage" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "passageChangedAt" TIMESTAMP(3);
