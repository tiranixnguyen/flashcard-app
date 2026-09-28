-- File nghe (MP3) lưu trong Postgres; thẻ gắn tối đa một file cho mỗi trường.
-- AlterTable
ALTER TABLE "Card" ADD COLUMN     "backAudioId" TEXT,
ADD COLUMN     "frontAudioId" TEXT,
ADD COLUMN     "hintAudioId" TEXT,
ADD COLUMN     "noteAudioId" TEXT;

-- CreateTable
CREATE TABLE "Audio" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "bytes" BYTEA NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Audio_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Audio_userId_sha256_key" ON "Audio"("userId", "sha256");

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_frontAudioId_fkey" FOREIGN KEY ("frontAudioId") REFERENCES "Audio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_backAudioId_fkey" FOREIGN KEY ("backAudioId") REFERENCES "Audio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_hintAudioId_fkey" FOREIGN KEY ("hintAudioId") REFERENCES "Audio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_noteAudioId_fkey" FOREIGN KEY ("noteAudioId") REFERENCES "Audio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Audio" ADD CONSTRAINT "Audio_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

