# wgc-run

A neovim plugin to run programs. Can be used to run things like 
'cargo run' for a rust project or 'love <root_dir>' for a love project.

## Configuration
The setup function for this plugin receives a table that can have the
following keys:
* buffer_keymaps (optional)
* runners (required)

### buffer_keymaps
This entry id a function that takes in the info object and creates 
any keymaps desired for the current buffer. Here where can map keystrokes
to the WgcRun command for the current buffer.

### runners
runners is a tables of runner definitions that describe how to run 
a program when in a buffer. For example if are in a rust file and
want to run 'cargo run' for your project the runner definiton gives
neovim the info required to do this and will create a User command called
:WgcRun which will run the program and open a window which will show the
output of the program.

A runner definition is a table the following keys:
* name (required) - The name of the runner
* autopat (required) - A string that specifies that file pattern to match
for this runner. This is the same as the autopat used for autocmds in neovim.
If the file you open matches this autopat the :WgcRun command will be created
for your buffer.
* run_tests (optional)- A list of tests that will be run when
you open a file that matchs autopat. All these tests must pass or the WgcRun
command will not be created for your buffer. The 'run_tests' table can have
any of the following keys:
    * file_exists - can be either a string or list of strings that are file(s) 
    that must exist in the same folder as the current file of any parent folder.
    If the file(s) are not found the WgcRun command will no be created for the buffer.

    * exe_exists - can be either a string or list of strings that are executables
    that must exist on the PATH. If any of these exe's are not found the the :WgcRun
    user command will not be created for the buffer.

    * test - can be either a function or table of functions. The functions will be 
    called with the Info object from the BufEnter autocmd and return a boolean. If
    any of these test functions return false the the WgcRun command will not be
    created for the buffer.

* run_command (optional if project contains a .wgc_run file explained below) - A list
that defines the program to be run and it's arguments. The entries in this table
can be string,  a function that takes in the BufEnter info object and returns a string
argument or it can contain a special search_up table which can be used to create an
argument based on a file found be searching the folder containing the current buffer
and all it's parents for a file. The search up table has the following keys:
    * search_up (required): The name of the file to search for.
    * file_action (optional): A function that takes in the found file_path and returns
    a sting argument. Note: if no file_action entry is provided then the default
    action will be to return tostring(file) as an argument to run_command.

Note: The result of processing the run_command will be a list of strings that are 
passed to the vim.fn.jobstart as the cmd parameter.

The runner configs for the wgc-run plugin do not require a run_command definition.
You can put a file called .wgn_run in the root of your project. This will be a lua
file that defines the command to be run when :WgcRun command is called. The .wgc_run
file is a lua module that must return a lua table with the following keys:
* cmd (required) - A list of strings that will be passed as the the cmd arg to vim.fn.jobstart 
function.
* cwd (optional) - A string with the working directory to be used in the call to 
vim.fn.jobstart function.


## Example Config

```lua

require('wgc-run').setup {
      buffer_keymaps = function(info)
        -- Note: Use buffer = info.buf to make a buffer local key mapping
        vim.keymap.set('n', '<leader>w', ':WgcRun<cr>', { buffer = info.buf, silent = true })
      end,
      runners = {
        -- This runner works to run the 'love' game engine 
        -- from any lua file in a the love project.
        -- Note: to run a love project you call 'love <root_dir>'
        -- where <root_dir> is the folder containing the main.lua 
        -- file. So we define the run_command with the string arg 'love'
        -- and a search_up definition that finds the main.lua file and
        -- the returns tostring(f:parent()) on the main.lua file_path.
        {
          name = 'love',
          autopat = '*.lua',
          run_tests = {
            exe_exists = 'love',
            file_exists = 'main.lua',
          },
          run_command = {
            'love',
            {
              search_up = 'main.lua',
              file_action = function(f)
                return tostring(f:parent())
              end,
            },
          }
        },
        -- This runner works to run rust projects by calling 'cargo run'.
        -- It will only create the :WgcRun user command for the .rs buffer
        -- if there is Cargo.toml in the parent path of the .rs folder and
        -- if there is a cargo exe in the PATH.
        {
          name = 'rust',
          autopat = '*.rs',
          run_tests = {
            exe_exists = 'cargo',
            file_exists = 'Cargo.toml'
          },
          run_command = {
            'cargo',
            'run'
          }
        }
      }
    }
```


## Example .wgc_run file

```lua
return {
  cmd = { 'cargo', 'run', '-v' },
}
```
