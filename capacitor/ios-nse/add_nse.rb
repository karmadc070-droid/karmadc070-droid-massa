# 알림 사진 확장(NotificationService) 타겟을 Capacitor iOS 프로젝트에 붙이는 스크립트 (codemagic 이 매 빌드 실행)
require "xcodeproj"

bundle = ENV.fetch("BUNDLE_ID")
proj = Xcodeproj::Project.open("ios/App/App.xcodeproj")
app = proj.targets.find { |t| t.name == "App" } or abort("★ App 타겟을 못 찾았다")
if proj.targets.any? { |t| t.name == "NotificationService" }
  puts "NotificationService 이미 있음"
  exit 0
end

dt = app.build_configurations.first.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] || "15.0"
nse = proj.new_target(:app_extension, "NotificationService", :ios, dt, proj.products_group, :swift)

group = proj.main_group.new_group("NotificationService", "NotificationService")
nse.add_file_references([group.new_reference("NotificationService.swift")])
group.new_reference("Info.plist")

nse.build_configurations.each do |c|
  s = c.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"] = "#{bundle}.NotificationService"
  s["INFOPLIST_FILE"] = "NotificationService/Info.plist"
  s["GENERATE_INFOPLIST_FILE"] = "NO"
  s["PRODUCT_NAME"] = "$(TARGET_NAME)"
  s["SWIFT_VERSION"] = "5.0"
  s["TARGETED_DEVICE_FAMILY"] = "1,2"
  s["SKIP_INSTALL"] = "YES"
  team = app.build_configurations.find { |a| a.name == c.name }&.build_settings&.dig("DEVELOPMENT_TEAM")
  s["DEVELOPMENT_TEAM"] = team if team
end

# 앱이 확장을 먼저 빌드하고 PlugIns 폴더에 넣도록
app.add_dependency(nse)
embed = app.new_copy_files_build_phase("Embed Foundation Extensions")
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(nse.product_reference, true)
bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
# 스크립트 단계 뒤에 두면 'Cycle inside App' 이 날 수 있어 리소스 단계 바로 뒤로 옮긴다
res_i = app.build_phases.index(app.resources_build_phase)
app.build_phases.delete(embed)
app.build_phases.insert(res_i + 1, embed)

proj.save
ok = app.copy_files_build_phases.any? { |p| p.files.any? { |f| f.file_ref == nse.product_reference } }
abort("★ 확장 포함 단계 등록 실패") unless ok
puts "NotificationService 추가: #{bundle}.NotificationService (iOS #{dt})"
puts "App 빌드 단계: " + app.build_phases.map(&:display_name).join(" → ")