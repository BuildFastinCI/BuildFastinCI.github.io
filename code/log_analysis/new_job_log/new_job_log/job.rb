require 'active_record'
require 'activerecord-jdbcmysql-adapter'
class Job < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.176.34.85",
      username: "root",
      password: "root",
      database: "cll_data",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool:300
  )
end