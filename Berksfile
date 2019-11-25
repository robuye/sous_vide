source "https://supermarket.chef.io"

Dir.glob("cookbooks/*").map do |dir|
  cookbook File.basename(dir), path: dir
end

cookbook "java"
cookbook "elasticsearch"
cookbook "seven_zip", "< 3.1"
cookbook "tomcat"
cookbook "nginx"
cookbook "mysql"
