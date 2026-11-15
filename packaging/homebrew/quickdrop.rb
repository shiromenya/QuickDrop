cask "quickdrop" do
  version "0.1.0"
  sha256 :no_check # Replace with `shasum -a 256 QuickDrop.app.zip` for tagged releases

  url "https://github.com/shiromenya/QuickDrop/releases/download/v#{version}/QuickDrop.app.zip"
  name "QuickDrop"
  desc "Menu bar utility that illuminates screen edges to share dragged files via AirDrop"
  homepage "https://github.com/shiromenya/QuickDrop"

  depends_on macos: ">= :ventura"

  app "QuickDrop.app"

  zap trash: [
    "~/Library/Preferences/io.github.quickdrop.QuickDrop.plist",
  ]
end
