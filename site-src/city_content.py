# 도시별 소개 페이지(/city/<도시>.html, 3개 언어) 문구 — build.py 가 DB 에서 승인·활성 마사지사가 있는 도시만 골라 만든다.
# 키는 DB providers.city_code 와 같다. 동네 이름은 예시일 뿐이고, 실제 방문 가능 여부는 앱이 주소를 받아 알려 준다.
# 의료 효과를 약속하는 문장은 쓰지 않는다(이완·관리 목적, 의료 행위 아님).

UPDATED = "2026-11-13"

# 페이지를 만들 최소 활성 마사지사 수. 이보다 적으면 손님이 와도 예약이 안 잡혀 역효과다.
MIN_ACTIVE = 3

ORDER = ["hanoi", "hcmc", "danang", "khanhhoa"]
SLUG = {"hanoi": "ha-noi", "hcmc": "ho-chi-minh", "danang": "da-nang", "khanhhoa": "nha-trang"}

LABELS = {
 "ko": {"kicker": "도시별 안내", "title": "{name} 출장 마사지·홈뷰티 — 집·호텔 방문 | massa",
        "desc": "{name}에서 집이나 호텔 객실로 테라피스트를 부르는 출장 마사지·홈뷰티 예약. 아로마·스웨디시·타이·딥티슈, 네일·왁싱. 서비스 후 현장 결제.",
        "lead": "{name}에서 집이나 호텔 객실로 테라피스트를 부를 수 있습니다. 원하는 시간에 예약하고, 서비스가 끝난 뒤 현장에서 결제합니다.",
        "h_areas": "이런 곳으로 찾아갑니다", "areas_note": "방문 가능 여부는 앱에서 주소를 넣으면 바로 알려 드립니다. 너무 먼 곳은 예약 단계에서 미리 안내합니다.",
        "h_services": "예약할 수 있는 서비스",
        "services": ["마사지 — 아로마테라피, 스웨디시, 타이, 딥티슈 등", "홈 뷰티 — 네일, 왁싱, 각질 케어"],
        "h_steps": "예약은 네 단계", "steps": ["서비스와 테라피스트를 고릅니다", "코스와 시간을 정합니다 (60·90·120분)", "집 주소나 호텔·객실 번호를 입력합니다", "확인하면 끝. 결제는 서비스가 끝난 뒤 현장에서 합니다"],
        "h_hotel": "호텔에서 받을 때", "hotel": "예약할 때 호텔 이름, 객실 번호, 프런트 통과 방법을 함께 적어 주세요. 외부 방문자 등록이 필요한 호텔은 검색 단계에서 미리 알려 드립니다.",
        "h_types": "마사지 종류 자세히 보기", "h_cities": "다른 도시",
        "cta_app": "앱에서 예약하기", "cta_guide": "이용 방법 보기",
        "disclaimer": "massa가 제공하는 케어는 이완과 관리를 목적으로 하며 의료 행위가 아닙니다. 치료가 필요한 증상은 의료기관을 이용해 주세요.",
        "list_kicker": "도시별 안내", "list_h2": "도시별로 보기", "list_lead": "지금 테라피스트가 활동 중인 도시입니다."},
 "en": {"kicker": "By city", "title": "In-home & hotel massage in {name} | massa",
        "desc": "Book a massage or home beauty therapist to your home or hotel room in {name}. Aromatherapy, Swedish, Thai, deep tissue, nails and waxing. Pay on site after the session.",
        "lead": "Call a therapist to your home or hotel room in {name}. Book the time that suits you and pay on site once the session is over.",
        "h_areas": "Where we come to", "areas_note": "Enter your address in the app and it tells you right away whether a visit is possible. Places too far away are flagged before you book.",
        "h_services": "What you can book",
        "services": ["Massage — aromatherapy, Swedish, Thai, deep tissue and more", "Home beauty — nails, waxing, exfoliation care"],
        "h_steps": "Four steps", "steps": ["Pick a service and a therapist", "Choose your course and time (60 / 90 / 120 minutes)", "Enter your address, or your hotel and room number", "Confirm. You pay on site after the session"],
        "h_hotel": "Booking at a hotel", "hotel": "Add the hotel name, room number and how the therapist should pass reception when you book. Hotels that require visitor registration are flagged during search.",
        "h_types": "Massage types in detail", "h_cities": "Other cities",
        "cta_app": "Book in the app", "cta_guide": "How booking works",
        "disclaimer": "Care provided through massa is for relaxation and wellbeing, not medical treatment. Please see a doctor for symptoms that need treatment.",
        "list_kicker": "By city", "list_h2": "Browse by city", "list_lead": "Cities where therapists are active now."},
 "vi": {"kicker": "Theo thành phố", "title": "Massage tại nhà {name} — đến tận nhà, khách sạn | massa",
        "desc": "Đặt kỹ thuật viên massage và làm đẹp đến tận nhà hoặc phòng khách sạn tại {name}. Aroma, Thụy Điển, Thái, deep tissue, nail, waxing. Thanh toán tại chỗ sau khi xong.",
        "lead": "Gọi kỹ thuật viên đến tận nhà hoặc phòng khách sạn tại {name}. Đặt đúng giờ bạn rảnh và thanh toán tại chỗ sau khi xong.",
        "h_areas": "Chúng tôi đến những nơi như", "areas_note": "Nhập địa chỉ trong ứng dụng để biết ngay có đến được không. Nơi quá xa sẽ được báo trước khi đặt.",
        "h_services": "Dịch vụ có thể đặt",
        "services": ["Massage — aroma, Thụy Điển, Thái, deep tissue và nhiều loại khác", "Làm đẹp tại nhà — nail, waxing, tẩy tế bào chết"],
        "h_steps": "Đặt lịch bốn bước", "steps": ["Chọn dịch vụ và kỹ thuật viên", "Chọn gói và giờ (60 / 90 / 120 phút)", "Nhập địa chỉ nhà hoặc tên khách sạn và số phòng", "Xác nhận là xong. Thanh toán tại chỗ sau khi xong"],
        "h_hotel": "Khi đặt tại khách sạn", "hotel": "Ghi tên khách sạn, số phòng và cách đi qua lễ tân khi đặt. Khách sạn yêu cầu đăng ký khách đến thăm sẽ được báo ngay khi tìm kiếm.",
        "h_types": "Xem chi tiết từng loại massage", "h_cities": "Thành phố khác",
        "cta_app": "Đặt lịch trong ứng dụng", "cta_guide": "Xem cách đặt lịch",
        "disclaimer": "Dịch vụ trên massa nhằm thư giãn và chăm sóc, không phải điều trị y tế. Nếu có triệu chứng cần điều trị, vui lòng đến cơ sở y tế.",
        "list_kicker": "Theo thành phố", "list_h2": "Xem theo thành phố", "list_lead": "Các thành phố đang có kỹ thuật viên hoạt động."},
}

# name: 도시 이름, areas: 예시 동네·숙소(방문 보장 아님)
CITIES = {
 "ko": {
  "hanoi": {"name": "하노이", "areas": ["호안끼엠 구시가지 주변 호텔", "떠이호 서호 주변 아파트", "미딩·꺼우저이 아파트 단지", "바딘·동다 주거지"]},
  "hcmc": {"name": "호찌민", "areas": ["1군·3군 시내 호텔", "7군 푸미흥 아파트", "타오디엔(투득) 빌라·아파트", "빈탄 주거지"]},
  "danang": {"name": "다낭", "areas": ["미케 해변 주변 호텔", "선짜 반도 리조트·아파트", "하이쩌우 시내", "응우하인선 주거지"]},
  "khanhhoa": {"name": "나짱", "areas": ["쩐푸 해변 도로 호텔", "시내 중심가 아파트", "해안가 리조트"]},
 },
 "en": {
  "hanoi": {"name": "Hanoi", "areas": ["Hotels around the Hoan Kiem Old Quarter", "Apartments around West Lake (Tay Ho)", "My Dinh and Cau Giay apartment blocks", "Ba Dinh and Dong Da neighbourhoods"]},
  "hcmc": {"name": "Ho Chi Minh City", "areas": ["Hotels in District 1 and District 3", "Phu My Hung apartments in District 7", "Villas and apartments in Thao Dien (Thu Duc)", "Binh Thanh neighbourhoods"]},
  "danang": {"name": "Da Nang", "areas": ["Hotels along My Khe beach", "Resorts and apartments on the Son Tra peninsula", "Hai Chau city centre", "Ngu Hanh Son neighbourhoods"]},
  "khanhhoa": {"name": "Nha Trang", "areas": ["Hotels along Tran Phu beach road", "Apartments in the city centre", "Seafront resorts"]},
 },
 "vi": {
  "hanoi": {"name": "Hà Nội", "areas": ["Khách sạn quanh phố cổ Hoàn Kiếm", "Căn hộ quanh Hồ Tây (Tây Hồ)", "Chung cư Mỹ Đình, Cầu Giấy", "Khu dân cư Ba Đình, Đống Đa"]},
  "hcmc": {"name": "TP. Hồ Chí Minh", "areas": ["Khách sạn Quận 1, Quận 3", "Căn hộ Phú Mỹ Hưng, Quận 7", "Biệt thự, căn hộ Thảo Điền (Thủ Đức)", "Khu dân cư Bình Thạnh"]},
  "danang": {"name": "Đà Nẵng", "areas": ["Khách sạn dọc biển Mỹ Khê", "Resort, căn hộ bán đảo Sơn Trà", "Trung tâm Hải Châu", "Khu dân cư Ngũ Hành Sơn"]},
  "khanhhoa": {"name": "Nha Trang", "areas": ["Khách sạn đường Trần Phú ven biển", "Căn hộ trung tâm thành phố", "Resort ven biển"]},
 },
}