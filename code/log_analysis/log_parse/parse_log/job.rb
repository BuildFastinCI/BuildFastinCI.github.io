# require 'active_record'
require 'activerecord-jdbcmysql-adapter'
class Job < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool:300
  )

end

#tests ok
# Job.where("id>10 and id<20").find_each do |item|
#     p item.id
# end