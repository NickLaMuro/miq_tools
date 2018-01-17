#!/usr/bin/python
#
# Author:  Nick LaMuro
#
# Original Licence from memdump.py : All samples are "Public Domain" code 
# http://en.wikipedia.org/wiki/Public_domain_software
#
# This code is modified forms of the following:
#   
#   - https://gist.github.com/csfrancis/11376304#file-gdb_ruby_backtrace-py
#   - https://gist.github.com/akhin/2a735ba0b11be52b691831499d7e8fa4/raw/c4140a50fbab088aff68b6e4322758afe779b5c3/memdump.py
#
# More info can be found for each respectively at the following links:
#
#   - https://engineering.shopify.com/blogs/engineering/adventures-in-production-rails-debugging
#   - https://nativecoding.wordpress.com/2016/07/31/gdb-debugging-automation-with-python/
#
# Updated to use more of gdb's internal Python API to make it more flexible,
# easier to use from the CLI, and re-usable in other situations.
#
# Meant for debugging c memory leaks in ruby.
#

import pprint

try:
    import gdb
except ImportError as e:
    raise ImportError("This script must be run in GDB: ", str(e))

string_t = None

class RubyEval (gdb.Command):
  """Eval a string of ruby code"""

  def __init__ (self):
    super (RubyEval, self).__init__ ("ruby_eval", gdb.COMMAND_USER)

  def invoke (self, ruby_code, from_tty):
    argv = gdb.string_to_argv (ruby_code) # just used for arg checking
    if len(argv) == 0:
      raise Exception("ruby_eval requires some ruby to execute")
    print RubyEval.ruby_eval(ruby_code)

  @staticmethod
  def ruby_eval(code):
    gdb.execute("call rb_eval_string(" + code + ")")

class GetRString (gdb.Command):
  """Get a RString value from a memory location"""

  def __init__ (self):
    super (GetRString, self).__init__ ("get_rstring", gdb.COMMAND_USER)

  def invoke (self, args, from_tty):
    argv = gdb.string_to_argv (args)
    if len(argv) > 1:
      raise Exception("get_rstring only accepts on argument")
    print GetRString.get_rstring(addr)

  @staticmethod
  def get_rstring(addr):
    s = addr.cast(string_t.pointer())
    if s['basic']['flags'] & (1 << 13):
      return s['as']['heap']['ptr'].string()
    else:
      return s['as']['ary'].string()

class GetRubyLineNumber (gdb.Command):
  """Get a line number from a iseq and pos"""

  def __init__ (self):
    super (GetRubyLineNumber, self).__init__ ("get_ruby_lineno", gdb.COMMAND_USER)

  def invoke (self, args, from_tty):
    argv = gdb.string_to_argv (args)
    if len(argv) != 2:
      raise Exception("get_ruby_lineno only accepts a iseq and pos")
    print GetRubyLineNumber.get_lineno(argv[0], argv[1])

  @staticmethod
  def get_lineno(iseq, pos):
    if pos != 0:
      pos -= 1
    t = iseq['line_info_table']
    t_size = iseq['line_info_size']

    if t_size == 0:
      return 0
    elif t_size == 1:
      return t[0]['line_no']

    for i in range(0, int(t_size)):
      if pos == t[i]['position']:
        return t[i]['line_no']
      elif t[i]['position'] > pos:
        return t[i-1]['line_no']

    return t[t_size-1]['line_no']

class GetRubyStacktrace (gdb.Command):
  """Get the ruby stacktrace for the current thread, or for a thread pointer
  
  Passing no argument will get you the ruby stacktrace of the active thread of
  the currently halted program.

  To get the thread id of a different thread, run the following:

  (gdb) info threads            # list threads with numerical ids
  (gdb) thread 3                # switches threads
  (gdb) where                   # lists the c stacktrace of current thread

  From the output of `where`, you should be able to find a thread_start_func_1
  and the value of 'th_ptr=' on that line is what you pass to `ruby_stacktrace`

  (gdb) ruby_stacktrace 0x7fed6cd81800
  """

  def __init__ (self):
    super (GetRubyStacktrace, self).__init__ ("ruby_stacktrace", gdb.COMMAND_USER)

  def invoke (self, args, from_tty):
    argv = gdb.string_to_argv (args)
    if len(argv) > 1:
      raise Exception("ruby_stacktrace only accepts a single thread id")

    thread_addr = None
    if len(argv) == 1:
      thread_addr = argv[0]

    print GetRubyStacktrace.get_ruby_stacktrace(thread_addr)

  @staticmethod
  def get_ruby_stacktrace(th=None):
    """Gets the ruby stacktrace from the current thread, or passed in th addr
    
    Is a static method that can be triggered from the gdb.Command,
    'ruby_stacktrace', or called from other commands/scripts using
    GetRubyStacktrace.get_ruby_stacktrace directly
    """
    global string_t
  
    try:
      control_frame_t = gdb.lookup_type('rb_control_frame_t')
      string_t = gdb.lookup_type('struct RString')
    except gdb.error:
      raise gdb.GdbError ("ruby extension requires symbols")
  
    if th == None:
      th = gdb.parse_and_eval('ruby_current_thread')
    else:
      th = gdb.parse_and_eval('(rb_thread_t *) %s' % th)
  
    last_cfp = th['cfp']
    start_cfp = (th['stack'] + th['stack_size']).cast(control_frame_t.pointer()) - 2
    size = start_cfp - last_cfp + 1
    cfp = start_cfp
    call_stack = []
    for i in range(0, int(size)):
      if cfp['iseq'].dereference().address != 0:
        if cfp['pc'].dereference().address != 0:
          s = "{}:{}:in `{}'".format(GetRString.get_rstring(cfp['iseq']['body']['location']['path']),
            GetRubyLineNumber.get_lineno(cfp['iseq']['body'], cfp['pc'] - cfp['iseq']['body']['iseq_encoded']),
            GetRString.get_rstring(cfp['iseq']['body']['location']['label']))
          call_stack.append(s)
  
      cfp -= 1
  
    for i in reversed(call_stack):
      print(i)

class ConsoleColorCodes:
  RED = '\033[91m'
  BLUE = '\033[94m'
  YELLOW = '\033[93m'
  END = '\033[0m'

class Utility:       
  max_stack_depth = 64

  @classmethod
  def set_max_stack_depth (cls, new_max_stack_depth):
    cls.max_stack_depth = new_max_stack_depth

  @staticmethod
  def writeColorMessage(message, colorCode):
    print(  colorCode + message + ConsoleColorCodes.END )

  @staticmethod
  def writeMessage(message):
    Utility.writeColorMessage(message, ConsoleColorCodes.BLUE)

  @staticmethod
  def writeErrorMessage(message):
    Utility.writeColorMessage(message, ConsoleColorCodes.RED)

  # @staticmethod
  # def logInfoMessage(message):
  #     global logFileName
  #     with open(str(logFileName), 'a') as logFile:
  #         logFile.write(str(message))

  @staticmethod
  def writeInfoMessage(message):
    # Utility.logInfoMessage(message)
    Utility.writeColorMessage(message, ConsoleColorCodes.YELLOW)

  @staticmethod
  def convertToHexString(input):
    output = int(input)
    output = hex(output)
    output = str(output)
    return output

  @staticmethod
  def appendCallstack(message):
    callstack = []
    depth = 1
    frame = gdb.selected_frame()
    while True:
      if (frame) and ( depth <= Utility.max_stack_depth ):
        if frame.name() != None:
          current_frame_name  = str(frame.name())
          symtab_and_line = frame.find_sal()
          file_and_line   = ""
          if ( symtab_and_line != None ) and ( symtab_and_line.symtab != None):
            file_and_line += ConsoleColorCodes.BLUE
            file_and_line += str(symtab_and_line.symtab.fullname()) + ":"
            file_and_line += str(symtab_and_line.line)
            file_and_line += ConsoleColorCodes.YELLOW
          callstack.append("%-40s%s" % (current_frame_name, file_and_line))
        frame = frame.older()
        depth += 1
      else:
        gdb.Frame.select ( gdb.newest_frame() )
        break

    message = str(message) + "\ncallstack : "
    for callstack_frame in callstack:
      message += "\n\t"
      message += str(callstack_frame)

    return message
      

class MallocBreakpoint (gdb.Breakpoint):
  def __init__ (self):
    super (MallocBreakpoint, self).__init__ ("__libc_malloc")

  def stop (self):
    message = "\ntype : malloc"
    message = Utility.appendCallstack(message)
    message += ConsoleColorCodes.RED + "\n\nruby callstack:\n" + ConsoleColorCodes.END
    Utility.writeInfoMessage(message)
    GetRubyStacktrace.get_ruby_stacktrace()
    return False

class CallocBreakpoint (gdb.Breakpoint):
  def __init__ (self):
    super (CallocBreakpoint, self).__init__ ("__libc_calloc")

  def stop (self):
    message = "\ntype : calloc"
    Utility.appendCallstack(message)
    Utility.writeInfoMessage(message)
    return False

class ReallocBreakpoint (gdb.Breakpoint):
  def __init__ (self):
    super (ReallocBreakpoint, self).__init__ ("__libc_realloc")

  def stop (self):
    message = "\ntype : realloc"
    Utility.appendCallstack(message)
    Utility.writeInfoMessage(message)
    return False

class FreeBreakpoint (gdb.Breakpoint):
  def __init__ (self):
    super (FreeBreakpoint, self).__init__ ("__libc_free")

  def stop (self):
    message = "\ntype : realloc"
    Utility.appendCallstack(message)
    Utility.writeInfoMessage(message)
    return False


class SetCStackDepth (gdb.Command):
  def __init__ (self):
    super (SetCStackDepth, self).__init__ ("set_c_stack_depth", gdb.COMMAND_USER)

  def invoke (self, args, from_tty):
    argv = gdb.string_to_argv (args)
    if len(argv) != 1:
      raise Exception("set_c_stack_depth takes exactly 1 argument")
    Utility.set_max_stack_depth(int(argv[0]))


class ToggleMemBreakpoints (gdb.Command):
  """Toggle on/off the memory allocation breakpoint logging from above"""

  malloc_breakpoint  = None
  calloc_breakpoint  = None
  realloc_breakpoint = None
  free_breakpoint    = None

  def __init__ (self):
    super (ToggleMemBreakpoints, self).__init__ ("toggle_mem_breakpoints", gdb.COMMAND_USER)

  def invoke (self, args, from_tty):
    argv = gdb.string_to_argv (args)
    if len(argv) > 0:
      raise Exception("toggle_mem_breakpoints doesn't take any arguments")
    ToggleMemBreakpoints.toggle_breakpoints()

  @classmethod
  def toggle_breakpoints (cls):
    if cls.malloc_breakpoint == None:
      cls.malloc_breakpoint = MallocBreakpoint()
    else:
      cls.malloc_breakpoint.delete()
      cls.malloc_breakpoint = None

    if cls.calloc_breakpoint == None:
      cls.calloc_breakpoint = CallocBreakpoint()
    else:
      cls.calloc_breakpoint.delete()
      cls.calloc_breakpoint = None

    if cls.realloc_breakpoint == None:
      cls.realloc_breakpoint = ReallocBreakpoint()
    else:
      cls.realloc_breakpoint.delete()
      cls.realloc_breakpoint = None

    if cls.free_breakpoint == None:
      cls.free_breakpoint = FreeBreakpoint()
    else:
      cls.free_breakpoint.delete()
      cls.free_breakpoint = None

# Set some needed options
gdb.execute("set pagination off")

# Define the commands
RubyEval()
GetRString()
GetRubyLineNumber()
GetRubyStacktrace()
SetCStackDepth()
ToggleMemBreakpoints()
