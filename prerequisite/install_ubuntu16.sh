sudo wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
sudo wget https://apt.repos.intel.com/setup/intelproducts.list -O /etc/apt/sources.list.d/intelproducts.list
sudo sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list'
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y intel-mkl-2018.2-046 
sudo apt-get install -y libx11-dev libboost-dev cmake swig flex libtool zlib1g-dev tcl-dev
