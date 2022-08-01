Các thao tác trên âm tiết là 1 chuỗi ký tự utf-8 bao gồm:

- Dùng `bytes_in_set` để đánh dấu nguyên âm ascii `qrtpdghklxcvbnm` (16 chars)

- toLower(): convert thành toàn bộ âm thường

- utf8Mark(): để đánh dấu bytes thuộc utf-8

- extractTone(): lọc tone ra khỏi âm tiết `mượn => mươn + j_tone`
  1/ é ý ú í ó á ế ứ ớ ố ắ ấ : 12 * ~2 ~= 24-byte
  2/ è
  3/ ẻ
  4/ ẽ
  5/ ẹ
