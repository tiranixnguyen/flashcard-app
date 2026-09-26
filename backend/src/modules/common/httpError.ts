/** Lỗi nghiệp vụ có mã HTTP đi kèm — `handle` đổi thành response tương ứng. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}
