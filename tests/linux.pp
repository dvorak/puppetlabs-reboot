file { '/tmp/before.txt':
  content   => 'one',
  before    => File['/tmp/after.txt']
}

reboot { 'now':
  prompt    => true,
  subscribe => File['/tmp/before.txt']
}

file { '/tmp/after.txt':
  content   => 'two'
}
