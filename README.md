# Dự án Dữ liệu Bán lẻ - Retail OLAP & Data Warehouse

Chào mừng bạn đến với kho lưu trữ mã nguồn của dự án xây dựng hệ thống **Kho dữ liệu (Data Warehouse) và Phân tích đa chiều (OLAP)** trực quan dành cho hệ thống bán lẻ trực tuyến.

## 📂 Kiến trúc và Thành phần Dự án

Dự án này là một quy trình hoàn chỉnh (End-to-End) từ cục dữ liệu thô đến việc lên mô hình, phân tích và trực quan hóa:

*   **Nguồn dữ liệu (Source Data):**
    *   `online_retail.csv`: Tập dữ liệu thô đầu vào chứa thông tin chi tiết về các giao dịch bán lẻ trực tuyến.

*   **Mô hình hóa dữ liệu (Dimensional Modeling):** 
    *   `High-Level-Dimensional-Modeling-Workbook (3).xlsx`
    *   `Detailed-Dimensional-Modeling-Workbook-KimballU (5).xlsm`
    *   > Các hồ sơ thiết kế cấu trúc Data Warehouse tuân theo phương pháp tiên tiến của Kimball.

*   **Lập trình Cơ sở dữ liệu & Quá trình ETL:**
    *   Các file `SQLQuery1.sql`, `SQLQuery2.sql`, `SQLQuery3.sql`: Chứa các script tạo cấu trúc (Schema) Staging, các bảng Dimension/Fact trong Data Warehouse và các truy vấn hỗ trợ khác.
    *   📁 `Olapssis/`: Thư mục chứa project SQL Server Integration Services (SSIS) nhằm thực hiện quy trình ETL (Extract, Transform, Load) tự động nạp dữ liệu lên kho.

*   **Dịch vụ Phân tích đa chiều (SSAS - OLAP cubes):**
    *   `Retail_OLAP.dwproj`, `Olap.slnx`: Các project triển khai khối dữ liệu (Cube) thông qua SQL Server Analysis Services (SSAS).

*   **Trực quan hóa Dữ liệu (Data Visualization):**
    *   `Olapp.pbix`: Báo cáo Dashboard hoàn chỉnh và có tính tương tác mạnh mẽ được thiết kế trên **Power BI**, lấy dữ liệu và DAX measure trực tiếp từ kho OLAP.

*   **Tài liệu & Báo cáo:**
    *   `olapck.pdf`, `olapck (1).docx`: Báo cáo tổng kết toàn bộ dự án, mô tả chi tiết các phân tích cũng như cơ sở lý luận cho mô hình.

---

## 🛠️ Công nghệ (Tech Stack)

*   **Hệ quản trị CSDL:** Microsoft SQL Server
*   **Công cụ luân chuyển dữ liệu:** SQL Server Integration Services (SSIS)
*   **Phân tích đa chiều:** SQL Server Analysis Services (SSAS)
*   **Trực quan hóa:** Microsoft Power BI
*   **Phương pháp luận:** Kimball Data Warehousing

---

## 🚀 Hướng dẫn triển khai cơ bản

1. **Chuẩn bị CSDL:** Khởi tạo Data Warehouse trên SQL Server và chạy các script truy vấn (`SQLQuery*.sql`) để khởi tạo các bảng Dims và Facts.
2. **Quá trình ETL:** Mở project `Olapssis` bằng Visual Studio (đã cài đặt kèm SSDT), cấu hình lại chuỗi kết nối (Connection Strings) và thực thi các package để đẩy dữ liệu từ file `csv` sạch vào kho dữ liệu.
3. **Triển khai Cube OLAP:** Mở `Retail_OLAP.dwproj` trên Visual Studio, Process (Xử lý) khối dữ liệu và Deploy (Triển khai) lên máy chủ Analysis Services.
4. **Mở báo cáo PBI:** Mở `Olapp.pbix`, có thể bạn sẽ cần trỏ lại nguồn kết nối (Data Source) về server SSAS cục bộ của bạn, sau đó Refresh toàn bộ báo cáo.
