/*
  Warnings:

  - You are about to drop the column `audioUrl` on the `Card` table. All the data in the column will be lost.
  - You are about to drop the column `backText` on the `Card` table. All the data in the column will be lost.
  - You are about to drop the column `frontText` on the `Card` table. All the data in the column will be lost.
  - You are about to drop the column `imageUrl` on the `Card` table. All the data in the column will be lost.
  - You are about to drop the column `romanization` on the `Card` table. All the data in the column will be lost.
  - You are about to drop the column `description` on the `Deck` table. All the data in the column will be lost.
  - You are about to drop the column `languagePairId` on the `Deck` table. All the data in the column will be lost.
  - You are about to drop the column `ownerId` on the `Deck` table. All the data in the column will be lost.
  - You are about to drop the `LanguagePair` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `UserCardProgress` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `kr` to the `Card` table without a default value. This is not possible if the table is not empty.
  - Added the required column `position` to the `Card` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Card` table without a default value. This is not possible if the table is not empty.
  - Added the required column `vi` to the `Card` table without a default value. This is not possible if the table is not empty.
  - Added the required column `groupId` to the `Deck` table without a default value. This is not possible if the table is not empty.
  - Added the required column `position` to the `Deck` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Deck` table without a default value. This is not possible if the table is not empty.
  - Added the required column `userId` to the `Deck` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Card" DROP CONSTRAINT "Card_deckId_fkey";

-- DropForeignKey
ALTER TABLE "Deck" DROP CONSTRAINT "Deck_languagePairId_fkey";

-- DropForeignKey
ALTER TABLE "Deck" DROP CONSTRAINT "Deck_ownerId_fkey";

-- DropForeignKey
ALTER TABLE "UserCardProgress" DROP CONSTRAINT "UserCardProgress_cardId_fkey";

-- DropForeignKey
ALTER TABLE "UserCardProgress" DROP CONSTRAINT "UserCardProgress_userId_fkey";

-- AlterTable
ALTER TABLE "Card" DROP COLUMN "audioUrl",
DROP COLUMN "backText",
DROP COLUMN "frontText",
DROP COLUMN "imageUrl",
DROP COLUMN "romanization",
ADD COLUMN     "altAnswers" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "flagsChangedAt" TIMESTAMP(3),
ADD COLUMN     "hanja" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "hint" TEXT,
ADD COLUMN     "kr" TEXT NOT NULL,
ADD COLUMN     "marked" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "parentId" TEXT,
ADD COLUMN     "position" INTEGER NOT NULL,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "vi" TEXT NOT NULL;

-- AlterTable
ALTER TABLE "Deck" DROP COLUMN "description",
DROP COLUMN "languagePairId",
DROP COLUMN "ownerId",
ADD COLUMN     "groupId" TEXT NOT NULL,
ADD COLUMN     "position" INTEGER NOT NULL,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "userId" TEXT NOT NULL;

-- DropTable
DROP TABLE "LanguagePair";

-- DropTable
DROP TABLE "UserCardProgress";

-- CreateTable
CREATE TABLE "Group" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Group_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StudySession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "deckId" TEXT NOT NULL,
    "device" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3) NOT NULL,
    "attempted" INTEGER NOT NULL,
    "correct" INTEGER NOT NULL,
    "masteredCount" INTEGER NOT NULL,
    "totalCards" INTEGER NOT NULL,
    "completed" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StudySession_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Group_userId_position_idx" ON "Group"("userId", "position");

-- CreateIndex
CREATE INDEX "StudySession_userId_deckId_endedAt_idx" ON "StudySession"("userId", "deckId", "endedAt");

-- CreateIndex
CREATE INDEX "Card_deckId_position_idx" ON "Card"("deckId", "position");

-- CreateIndex
CREATE INDEX "Deck_groupId_position_idx" ON "Deck"("groupId", "position");

-- AddForeignKey
ALTER TABLE "Group" ADD CONSTRAINT "Group_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deck" ADD CONSTRAINT "Deck_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deck" ADD CONSTRAINT "Deck_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_deckId_fkey" FOREIGN KEY ("deckId") REFERENCES "Deck"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "Card"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StudySession" ADD CONSTRAINT "StudySession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StudySession" ADD CONSTRAINT "StudySession_deckId_fkey" FOREIGN KEY ("deckId") REFERENCES "Deck"("id") ON DELETE CASCADE ON UPDATE CASCADE;
