(defmodule cereal-srv
  (export all))

(include-lib "cereal/include/records.lfe")

(defun run (pid state-data)
  (receive
    (`#(,_ #(data ,bytes))
     (! pid `#(data ,bytes))
     (run pid state-data))
    (`#(send ,bytes)
     (port-cmd (state-port state-data) `(,(cereal-const:send) ,bytes))
     (run pid state-data))
    (#(connect)
     (port-cmd (state-port state-data) `(,(cereal-const:connect)))
     (run pid state-data))
    (#(disconnect)
     (port-cmd (state-port state-data) `(,(cereal-const:disconnect)))
     (run pid state-data))
    (`#(open ,tty)
     (port-cmd (state-port state-data) `(,(cereal-const:open) ,tty))
     (run pid state-data))
    (#(close)
     (logjam:debug (MODULE)
                   'run/2
                   "Preparing to close ~p and deregister ~p ..."
                   `(,(state-port state-data) ,(cereal-const:server-name)))
     (let (('ok (cereal:close-tty (state-fd state-data))))
       (erlang:port_close (state-port state-data))
       (erlang:unregister (cereal-const:server-name))
       (! pid #(ok closed))))
    (`#(speed ,in-speed ,out-speed)
     (port-cmd (state-port state-data)
               (list* (cereal-const:speed)
                      (cereal-util:convert-speed
                        in-speed
                        out-speed)))
     (run pid state-data))
    (`#(speed ,speed)
     (port-cmd (state-port state-data)
               (list* (cereal-const:speed)
                      (cereal-util:convert-speed speed)))
     (run pid state-data))
    (#(parity odd)
     (port-cmd (state-port state-data) `(,(cereal-const:parity-odd)))
     (run pid state-data))
    (#(parity even)
     (port-cmd (state-port state-data) `(,(cereal-const:parity-even)))
     (run pid state-data))
    (#(break)
     (port-cmd (state-port state-data) `(,(cereal-const:break)))
     (run pid state-data))
    (#(info)
     (! pid `#(data ,(erlang:port_info (state-port state-data))))
     (run pid state-data))
    (`#(EXIT ,port ,why)
     (logjam:error (MODULE) 'run/2 "Exited with reason: ~p~n" `(,why))
     (exit why))
    (msg
     (logjam:info (MODULE) 'run/2 "Received unknown message: ~p~n" `(,msg))
     (run pid state-data))))


(defun port-cmd (port data)
  (logjam:debug (MODULE)
                'port-cmd/2
                "Preparing to call port_command/2 with msg ~p to ~p ..."
                `(,data ,port))
  (erlang:port_command port data))
