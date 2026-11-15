-- massa 데일리 푸시에 오후 슬롯(하노이 16:00 = 서버 KST 18:00)을 더한다 (2026-11-15)
-- send_daily_push('afternoon') 은 기존 함수를 그대로 쓴다. 문구만 슬롯별로 7개(요일) 넣는다.
alter table public.daily_push_messages drop constraint daily_push_messages_slot_check;
alter table public.daily_push_messages add constraint daily_push_messages_slot_check
  check (slot = any (array['noon'::text, 'afternoon'::text, 'evening'::text]));

insert into public.daily_push_messages (dow, slot, title, body) values
(0, 'afternoon',
 '{"ko":"일요일 오후, 여유롭게","vi":"Chiều Chủ nhật thảnh thơi","en":"Easy Sunday afternoon","zh":"悠闲的周日下午","ja":"のんびり日曜の午後"}',
 '{"ko":"오늘 저녁 마사지를 앱에서 예약해 보세요","vi":"Đặt lịch massage tối nay ngay trên ứng dụng","en":"Book tonight''s massage in the app","zh":"在应用里预约今晚的按摩","ja":"今夜のマッサージをアプリで予約しましょう"}'),
(1, 'afternoon',
 '{"ko":"월요일 오후, 어깨 뻐근하죠?","vi":"Chiều thứ Hai, mỏi vai rồi?","en":"Stiff shoulders this Monday?","zh":"周一下午，肩膀酸了吗？","ja":"月曜の午後、肩がこっていませんか？"}',
 '{"ko":"퇴근 후 방문하도록 미리 예약해 두세요","vi":"Đặt trước để kỹ thuật viên đến sau giờ làm","en":"Book now and your therapist comes after work","zh":"提前预约，下班后理疗师上门","ja":"今予約すれば仕事の後にセラピストが伺います"}'),
(2, 'afternoon',
 '{"ko":"퇴근까지 몇 시간 남았어요","vi":"Còn vài giờ nữa là tan làm","en":"A few hours until the end of work","zh":"离下班只剩几个小时","ja":"仕事終わりまであと数時間"}',
 '{"ko":"지금 저녁 시간 테라피스트를 골라 두세요","vi":"Chọn kỹ thuật viên cho buổi tối ngay bây giờ","en":"Pick your therapist for this evening now","zh":"现在就选好今晚的理疗师","ja":"今夜のセラピストを今のうちに選びましょう"}'),
(3, 'afternoon',
 '{"ko":"주중 한가운데, 충전이 필요할 때","vi":"Giữa tuần, nạp lại năng lượng","en":"Midweek recharge","zh":"周中充个电","ja":"週の真ん中にリフレッシュ"}',
 '{"ko":"오늘 저녁 집이나 호텔에서 마사지 받아 보세요","vi":"Massage tại nhà hoặc khách sạn tối nay","en":"Massage at home or your hotel tonight","zh":"今晚在家或酒店享受按摩","ja":"今夜は自宅やホテルでマッサージを"}'),
(4, 'afternoon',
 '{"ko":"목요일 오후, 주말이 코앞","vi":"Chiều thứ Năm, sắp cuối tuần rồi","en":"Thursday afternoon, the weekend is close","zh":"周四下午，周末快到了","ja":"木曜の午後、週末はもうすぐ"}',
 '{"ko":"일찍 예약하면 원하는 시간을 잡기 쉬워요","vi":"Đặt lịch sớm để chọn được giờ bạn muốn","en":"Book early to get the time you want","zh":"早点预约，更容易约到想要的时间","ja":"早めの予約で希望の時間を取りやすく"}'),
(5, 'afternoon',
 '{"ko":"금요일이에요, 오늘 밤은 쉬기","vi":"Thứ Sáu rồi, tối nay thư giãn","en":"It''s Friday, unwind tonight","zh":"周五了，今晚好好放松","ja":"金曜日、今夜はゆっくり"}',
 '{"ko":"테라피스트가 찾아가니 편하게 쉬기만 하세요","vi":"Kỹ thuật viên đến tận nơi, bạn chỉ cần nghỉ ngơi","en":"Your therapist comes to you, just relax","zh":"理疗师上门，您只需放松","ja":"セラピストが伺うので、くつろぐだけ"}'),
(6, 'afternoon',
 '{"ko":"토요일 오후, 다리 아프죠?","vi":"Chiều thứ Bảy, đi chơi mỏi chân?","en":"Tired feet this Saturday?","zh":"周六下午，走累了吗？","ja":"土曜の午後、歩き疲れましたか？"}',
 '{"ko":"호텔로 돌아가 앱으로 마사지를 불러 보세요","vi":"Về khách sạn và đặt massage trên ứng dụng","en":"Head back to your hotel and book a massage in the app","zh":"回到酒店，在应用里预约按摩","ja":"ホテルに戻ってアプリでマッサージを"}');
