## installs java 8 and others in ubuntu 18.
sudo apt-get update
sudo apt-get -y install openjdk-8-jdk
sudo apt-get install python-minimal
sudo apt-get install maven
## set python 2 as the main
echo "Configure alternatives here such that python 2 is the default python"
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 2
sudo update-alternatives --config python
pip install cassandra-driver
sudo pip install cassandra-driver
