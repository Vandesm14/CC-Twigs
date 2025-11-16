test:
  rm -rf test/data
  mkdir -p test/data/computer/0
  cp test/startup.lua test/data/computer/0
  craftos --headless -i 0 -d "$(pwd)/test/data" --mount-ro "pkgs=$(pwd)/pkgs" > test/test.out
  tail -n 18 test/test.out
