-- CreateEnum
CREATE TYPE "DeckType" AS ENUM ('listening', 'speaking', 'reading', 'writing', 'grammar');

-- AlterTable
ALTER TABLE "Deck" ADD COLUMN     "type" "DeckType";
