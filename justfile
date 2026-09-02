test:
  rm -rf test/data
  mkdir -p test/data/computer/0
  cp test/startup.lua test/data/computer/0
  craftos --headless -i 0 -d "$(pwd)/test/data" --mount-ro "pkgs=$(pwd)/pkgs" > /dev/null
  cat test/data/computer/0/test-results.log

backup:
  mkdir -p temp
  tar -czf temp/202609011525_uploads.tar.gz uploads/
