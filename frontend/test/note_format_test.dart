import "package:flashcard_app/features/study_reading/domain/note_format.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("nestFlattenedLists", () {
    test("mục con sau tiêu đề đậm có ':' được thụt vào, tới dòng trống", () {
      const md = """
* **Nghĩa:** lo lắng
### **3 Use Cases:**

* **Use case 1 (Văn nói):**
* *Bối cảnh:* phân vân chọn áo
* *A:* "뭐 사지?" *(Mua gì nhỉ?)*

* **Use case 2:**
* *B:* "고민해"
* **Use case 3**:
* **문장:** "고민하고 있다." 
""";
      expect(nestFlattenedLists(md), """
* **Nghĩa:** lo lắng
### **3 Use Cases:**

* **Use case 1 (Văn nói):**
  * *Bối cảnh:* phân vân chọn áo
  * *A:* "뭐 사지?" *(Mua gì nhỉ?)*

* **Use case 2:**
  * *B:* "고민해"
* **Use case 3**:
  * **문장:** "고민하고 있다." 
""");
    });

    test("mục con thụt đúng tới chỗ nội dung mục cha (dấu dài / số)", () {
      expect(
        nestFlattenedLists("*   **Ví dụ:**\n*   một\n1. **Hai:**\n- hai"),
        "*   **Ví dụ:**\n    *   một\n1. **Hai:**\n   - hai",
      );
    });

    test("đã có thụt lề thật (Markdown gốc) thì giữ nguyên", () {
      const md =
          "* **Use case 1:**\n    * *Bối cảnh:* x\n* **Use case 2:**\n* y";
      expect(nestFlattenedLists(md), md);
    });

    test("không đụng vào khối code", () {
      const md = "* **Code:**\n```\n* không phải list\n```\n* sau code";
      expect(nestFlattenedLists(md), md);
    });

    test(
      "mục đậm không có ':' hoặc có chữ sau cụm đậm thì không là tiêu đề",
      () {
        const md = "* **Chú ý**\n* a\n* **Nghĩa:** lo lắng\n* b";
        expect(nestFlattenedLists(md), md);
      },
    );
  });
}
