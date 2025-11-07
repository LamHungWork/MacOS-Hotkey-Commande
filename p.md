# Kế hoạch phát triển ứng dụng "MacOS Hotkey Commander"

## Mục đích
Thực thi lệnh dòng lệnh trên macOS bằng cách nhấn tổ hợp phím tắt.

## Đối tượng người dùng
Người dùng macOS cần phím tắt nhanh để thực hiện các tác vụ.

## Nguyên tắc phát triển

*   **Đơn giản tối đa:** Giữ cho ứng dụng đơn giản và nhẹ nhất có thể.
*   **Tập trung vào hiệu năng:** Tối ưu hóa để đảm bảo không ảnh hưởng đến trải nghiệm người dùng trên macOS.
*   **Không mở rộng:** Chỉ tập trung vào các yêu cầu đã định nghĩa, không "over-skill" hay chuẩn bị cho các tính năng trong tương lai.
*   **Bám sát yêu cầu:** Luôn tuân thủ chặt chẽ các yêu cầu đã được liệt kê trong tài liệu này.

## Các tính năng chính

1.  **Chạy ngầm:** Ứng dụng sẽ chạy ẩn.
2.  **Tự khởi động:** Tự động khởi động cùng macOS.
3.  **Icon trên thanh Menu:** Một biểu tượng nhỏ trên thanh menu bar bên phải.
4.  **Menu tương tác:** Khi nhấp vào biểu tượng trên thanh menu, một menu sẽ hiển thị:
    *   Danh sách các cấu hình phím tắt hiện có (chỉ để xem, ví dụ: "S - open -a 'Google Chrome'").
    *   Một đường phân cách.
    *   Một nút "Cấu hình..." (Configure...).
    *   Một nút "Thoát" (Quit).
5.  **Cửa sổ cấu hình:** Nhấp vào nút "Cấu hình..." từ menu sẽ mở cửa sổ cấu hình. Tại đây, người dùng có thể:
    *   **Chỉnh sửa tổ hợp phím kích hoạt:** Cho phép người dùng thay đổi tổ hợp phím kích hoạt cơ sở (mặc định là `Control + Shift`).
    *   Xem danh sách các cặp phím tắt-lệnh đã cấu hình.
    *   Thêm mới: nhập "phím cấu hình" (ví dụ: "S") và lệnh cần thực thi (ví dụ: `open -a "Google Chrome"`).
    *   Chỉnh sửa các cặp đã có.
    *   Xóa các cặp đã có.
6.  **Kích hoạt bằng phím tắt:**
    *   **Tổ hợp phím kích hoạt có thể cấu hình:** Mặc định là `Control + Shift`, nhưng người dùng có thể thay đổi.
    *   Khi người dùng nhấn giữ tổ hợp phím kích hoạt đã cấu hình cùng với một "phím cấu hình" đã định nghĩa, lệnh dòng lệnh tương ứng sẽ được thực thi.
    *   Lệnh sẽ được thực hiện khi tổ hợp phím được giữ. (Lưu ý: "khi thả tổ hợp => tắt" sẽ được hiểu là hành động hoàn tất cho các lệnh như mở ứng dụng; đối với các lệnh chạy liên tục, cần làm rõ thêm).

## Công nghệ đề xuất

*   **Ngôn ngữ:** Swift
*   **Framework:** AppKit (cho giao diện người dùng và tích hợp hệ thống)
*   **Quản lý phím tắt:** `NSEvent` để theo dõi sự kiện toàn cục và thư viện `HotKey` (hoặc tương tự) để đăng ký phím tắt dễ dàng hơn.
*   **Thực thi lệnh:** `Process` (hoặc `NSTask`) để chạy các lệnh shell.
*   **Lưu trữ cấu hình:** `UserDefaults` hoặc Property Lists (`.plist`).

## Kế hoạch phát triển chi tiết

1.  **Khởi tạo ứng dụng macOS:** Tạo một ứng dụng AppKit cơ bản chạy ngầm.
2.  **Triển khai biểu tượng và Menu động:**
    *   Thiết lập biểu tượng trên thanh menu và biểu tượng cho ứng dụng (sẽ được cung cấp sau).
    *   Xây dựng menu động hiển thị danh sách cấu hình, nút "Cấu hình..." và "Thoát".
3.  **Phát triển cửa sổ cấu hình:**
    *   Thiết kế giao diện cửa sổ với khu vực chỉnh sửa tổ hợp phím kích hoạt, danh sách các lệnh, form thêm/sửa và nút xóa.
    *   Triển khai logic thêm, sửa, xóa cấu hình lệnh (tạm thời, chỉ áp dụng khi nhấn "Save").
    *   Triển khai logic thay đổi tổ hợp phím kích hoạt (tạm thời, chỉ áp dụng khi nhấn "Save").
    *   Triển khai nút "Save" (lưu tất cả thay đổi và đóng cửa sổ).
    *   Triển khai nút "Close" (đóng cửa sổ, hủy bỏ mọi thay đổi chưa lưu, không cảnh báo).
    *   **Quy tắc xác thực (Validation Rules):**
        *   Nút "Save" sẽ bị vô hiệu hóa nếu bất kỳ cấu hình nào không hợp lệ.
        *   **Tổ hợp phím kích hoạt:** Phải có ít nhất một phím.
        *   **Phím cấu hình (Key):** Phải là một ký tự duy nhất.
        *   **Lệnh (Command):** Không được để trống.
4.  **Triển khai trình lắng nghe phím tắt toàn cục:**
    *   Đăng ký lắng nghe sự kiện bàn phím toàn cục một cách linh động dựa trên cấu hình của người dùng.
    *   Xử lý phát hiện tổ hợp phím kích hoạt + "phím cấu hình".
    *   Thực thi lệnh tương ứng khi phím tắt được kích hoạt.
    *   Cập nhật trình lắng nghe khi người dùng thay đổi tổ hợp phím kích hoạt.
5.  **Lưu trữ và tải cấu hình:**
    *   Sử dụng `UserDefaults` để lưu trữ và tải cấu hình phím tắt, bao gồm cả tổ hợp phím kích hoạt.
6.  **Cấu hình tự khởi động:**
    *   Thiết lập ứng dụng để tự động khởi chạy khi đăng nhập macOS.
7.  **Quản lý quyền truy cập:**
    *   Đảm bảo ứng dụng yêu cầu các quyền cần thiết (ví dụ: quyền truy cập trợ năng để lắng nghe phím tắt toàn cục) chỉ một lần duy nhất khi khởi chạy lần đầu.
    *   Ưu tiên lưu trữ trạng thái cấp quyền để tránh hỏi lại người dùng không cần thiết.

## Mô tả giao diện

*   **Ngôn ngữ giao diện:** Toàn bộ văn bản trên giao diện người dùng sẽ được viết bằng tiếng Anh.

*   **Bản vẽ cửa sổ cấu hình:**

'''
+------------------------------------------------------------------+
| Hotkey Commander Settings                                        |
+------------------------------------------------------------------+
|                                                                  |
|  Activation Hotkey:   [ Control + Shift ]  [ Change ]            |
|  (Click 'Change' and press the new key combination)              |
|                                                                  |
|  --------------------------------------------------------------  |
|                                                                  |
|  Shortcuts:                                                      |
|  +------------------+----------------------------------+-------+ |
|  | Key              | Command                          |       | |
|  +------------------+----------------------------------+-------+ |
|  | S                | open -a "Google Chrome"          | [ x ] | |
|  | C                | open -a "Calculator"             | [ x ] | |
|  | T                | open -a "Terminal"               | [ x ] | |
|  |                  |                                  |       | |
|  +------------------+----------------------------------+-------+ |
|                                                                  |
|  [ + Add New ]                                                   |
|                                                                  |
+------------------------------------------------------------------+
|                                       [ Close ]  [ Save ]        |
+------------------------------------------------------------------+
'''
