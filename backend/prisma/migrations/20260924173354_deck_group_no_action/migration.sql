-- DropForeignKey
ALTER TABLE "Deck" DROP CONSTRAINT "Deck_groupId_fkey";

-- AddForeignKey
ALTER TABLE "Deck" ADD CONSTRAINT "Deck_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE NO ACTION ON UPDATE CASCADE;
