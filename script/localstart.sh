cd ..
rails runner "Worker.split_sets_loop" > ./log/split_log &
rails runner "Worker.upload_loop" > ./log/upload1_log &
rails runner "Worker.upload_loop" > ./log/upload2_log &
rails runner "Worker.upload_loop" > ./log/upload3_log &
rails runner "Worker.upload_loop" > ./log/upload4_log &
