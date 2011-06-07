#
#  test.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/6/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#


reader, writer = IO.pipe 
pid = spawn("echo '4*a(1)' | bc -l; sleep 2; echo 'end'", [ STDERR, STDOUT ] => writer) 
writer.close
while out = reader.gets do
  puts out
end
Process::waitpid2(pid) 
p reader.gets	# =>	"3.14159265358979323844\n"