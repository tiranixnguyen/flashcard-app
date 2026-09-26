/*
  Warnings:

  - You are about to drop the column `flagsChangedAt` on the `Card` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Card" DROP COLUMN "flagsChangedAt",
ADD COLUMN     "hanjaChangedAt" TIMESTAMP(3),
ADD COLUMN     "markedChangedAt" TIMESTAMP(3);
