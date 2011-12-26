ps auxww | grep 'rails runner' | grep -v 'grep' | awk '{print $2}' 
