cd ..
rails runner -e production "Worker.split_sets_loop" > ./log/split_log &
rails runner -e production "Worker.upload_loop_batch" > ./log/upload1_log &
rails runner -e production "Worker.upload_loop_batch" > ./log/upload2_log &
rails runner -e production "Worker.upload_loop_batch" > ./log/upload3_log &
rails runner -e production "Worker.upload_loop_batch" > ./log/upload4_log &
rails runner -e production "Worker.beanstalk_pusher" > ./log/beanstalk_log &
rails runner -e production "Worker.create_fb_albums" > ./log/fb_albums_log &
