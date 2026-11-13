-- CreateEnum
CREATE TYPE "DeckSource" AS ENUM ('snu3a', 'snu3b', 'snu4a', 'snu4b', 'thth3', 'thth4');

-- AlterTable
ALTER TABLE "Deck" ADD COLUMN     "source" "DeckSource";
