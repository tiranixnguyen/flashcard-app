import { describe, expect, it } from "vitest";
import { call, useTestServer } from "../../testing/testServer";
import { AUDIO_MAX_BYTES } from "./audioService";

/** Chạy trên Postgres dev thật (docker compose up -d), user test riêng. */
const server = useTestServer();
const api = (method: string, path: string, body?: unknown) =>
  call(server.baseUrl, method, path, body);

/** "MP3" giả: thẻ ID3 + đuôi riêng để mỗi file một nội dung. */
const mp3 = (tail: string) => Buffer.concat([Buffer.from("ID3\x04\x00"), Buffer.from(tail)]);

async function upload(bytes: Buffer, type = "audio/mpeg") {
  const res = await fetch(`${server.baseUrl}/audio`, {
    method: "POST",
    headers: { "Content-Type": type },
    body: new Uint8Array(bytes),
  });
  return { status: res.status, json: await res.json() };
}

async function makeCard() {
  const g = await api("POST", "/groups", { name: "G" });
  const d = await api("POST", "/decks", {
    groupId: g.json.id,
    name: "Bài 1",
    words: [{ back: "가다", front: "đi" }],
  });
  return d.json.cards[0] as { id: string; front: string; back: string };
}

describe("tải lên file nghe", () => {
  it("lưu MP3, tải lại cùng nội dung ra cùng id", async () => {
    const a = await upload(mp3("một"));
    expect(a.status).toBe(201);
    expect(a.json).toMatchObject({ size: mp3("một").length });
    const again = await upload(mp3("một"));
    expect(again.json.id).toBe(a.json.id);
    const other = await upload(mp3("hai"));
    expect(other.json.id).not.toBe(a.json.id);
  });

  it("từ chối: không phải MP3, sai Content-Type, rỗng, quá lớn — luôn trả JSON", async () => {
    expect(await upload(Buffer.from("\x89PNG...."))).toMatchObject({
      status: 415,
      json: { error: "Chỉ nhận file MP3." },
    });
    expect((await upload(mp3("x"), "application/octet-stream")).status).toBe(415);
    expect((await upload(Buffer.alloc(0))).status).toBe(400);
    const big = await upload(Buffer.concat([mp3(""), Buffer.alloc(AUDIO_MAX_BYTES)]));
    expect(big).toMatchObject({ status: 413, json: { error: "Dữ liệu gửi lên quá lớn." } });
  });
});

describe("phát file nghe", () => {
  it("trả đủ file kèm cache vĩnh viễn; ETag khớp -> 304", async () => {
    const { json } = await upload(mp3("0123456789"));
    const res = await fetch(`${server.baseUrl}/audio/${json.id}`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("audio/mpeg");
    expect(res.headers.get("cache-control")).toContain("immutable");
    expect(res.headers.get("accept-ranges")).toBe("bytes");
    expect(Buffer.from(await res.arrayBuffer())).toEqual(mp3("0123456789"));

    const etag = res.headers.get("etag")!;
    const cached = await fetch(`${server.baseUrl}/audio/${json.id}`, {
      headers: { "If-None-Match": etag },
    });
    expect(cached.status).toBe(304);
  });

  it("Range -> 206 đúng đoạn (AVPlayer cần để phát/tua); ngoài file -> 416", async () => {
    const bytes = mp3("0123456789");
    const { json } = await upload(bytes);
    const part = await fetch(`${server.baseUrl}/audio/${json.id}`, {
      headers: { Range: "bytes=0-1" },
    });
    expect(part.status).toBe(206);
    expect(part.headers.get("content-range")).toBe(`bytes 0-1/${bytes.length}`);
    expect(Buffer.from(await part.arrayBuffer()).toString()).toBe("ID");

    const bad = await fetch(`${server.baseUrl}/audio/${json.id}`, {
      headers: { Range: `bytes=${bytes.length}-` },
    });
    expect(bad.status).toBe(416);
  });

  it("id không tồn tại -> 404", async () => {
    expect((await api("GET", "/audio/khong-co")).status).toBe(404);
  });
});

describe("gắn file nghe vào thẻ", () => {
  it("gắn từng trường, bỏ trống thì giữ, null thì gỡ; /content trả kèm id", async () => {
    const card = await makeCard();
    const front = (await upload(mp3("front"))).json.id;
    const note = (await upload(mp3("note"))).json.id;
    const base = { front: card.front, back: card.back };

    const set = await api("PATCH", `/cards/${card.id}`, {
      ...base,
      frontAudioId: front,
      noteAudioId: note,
    });
    expect(set.status).toBe(200);
    expect(set.json).toMatchObject({
      frontAudioId: front,
      backAudioId: null,
      hintAudioId: null,
      noteAudioId: note,
    });

    const kept = await api("PATCH", `/cards/${card.id}`, { ...base, noteAudioId: null });
    expect(kept.json).toMatchObject({ frontAudioId: front, noteAudioId: null });

    const content = await api("GET", "/content");
    expect(content.json.decks[0].cards[0]).toMatchObject({ frontAudioId: front });
    expect(content.json.decks[0].cards[0]).not.toHaveProperty("bytes");
  });

  it("id file nghe không có / sai kiểu -> 400, thẻ không đổi", async () => {
    const card = await makeCard();
    const base = { front: card.front, back: card.back };
    const missing = await api("PATCH", `/cards/${card.id}`, { ...base, backAudioId: "khong-co" });
    expect(missing.status).toBe(400);
    const wrongType = await api("PATCH", `/cards/${card.id}`, { ...base, hintAudioId: 1 });
    expect(wrongType.status).toBe(400);
    const content = await api("GET", "/content");
    expect(content.json.decks[0].cards[0].backAudioId).toBeNull();
  });

  it("xoá thẻ không xoá file nghe (dọn bằng prune-audio)", async () => {
    const card = await makeCard();
    const id = (await upload(mp3("giữ"))).json.id;
    await api("PATCH", `/cards/${card.id}`, {
      front: card.front,
      back: card.back,
      backAudioId: id,
    });
    expect((await api("DELETE", `/cards/${card.id}`)).status).toBe(204);
    expect((await fetch(`${server.baseUrl}/audio/${id}`)).status).toBe(200);
  });
});
