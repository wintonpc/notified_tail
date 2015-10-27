# NotifiedTail

`tail -f` for ruby using inotify/kqueue to avoid polling. Polling adds
latency and overhead. Falls back to polling on platforms where neither
inotify nor kqueue are supported.

Inspired by http://rubyforadmins.com/reading-growing-files

```ruby
require 'notified_tail'
NotifiedTail.tail(file_path) do |line|
  puts line
end
```
