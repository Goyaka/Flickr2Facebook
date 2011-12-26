cd /opt/Flickr2Facebook
sudo nohup rails runner -e production "Worker.split_sets_loop" > ./log/split_log &
sudo nohup rails runner -e production "Worker.upload_loop" > ./log/upload1_log &
sudo nohup rails runner -e production "Worker.upload_loop" > ./log/upload2_log &
sudo nohup rails runner -e production "Worker.upload_loop" > ./log/upload3_log &
sudo nohup rails runner -e production "Worker.upload_loop" > ./log/upload4_log &
