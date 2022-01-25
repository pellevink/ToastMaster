# ToastMaster
A simple addon for adding toasts to wow clients v.1.12

## Usage
If you'd like to use ToastMaster for toast alerts in an addon, simply add it as an OptionalDep or Dependency in your .toc file.
Then use the global object ToastMaster to access it's API.

ToastMaster:AddToast(title, text)

Adds a toast to the screen

ToastMaster:UnlockFrame()

Unlocks the ToastMaster pane and makes it movable

ToastMaster:LockFrame()

Locks the frame again, and stores its position to saved variables.