#!/bin/bash
ansible_commands=(
#"ansible-playbook -vv -i inventory.yaml hyperv.yaml > /home/andrei/ansible_test/h.log 2>&1 &"
"ansible-playbook -vv -i inventory.yaml devstack.yaml > /home/andrei/ansible_test/d.log 2>&1 &"
)

#===================== Parameters =====================
REQUIRED_VARS=(
ZUUL_PROJECT
ZUUL_BRANCH
ZUUL_CHANGE
ZUUL_PATCHSET
)

# check if all required vars are defined
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var+x}" ]; then 
        UNSET_VARS+=($var)
    fi
done

# if any variables are not set print an error and exit
if (( ${#UNSET_VARS[@]} ));then
    echo "The following variables are not set: ${UNSET_VARS[@]}"
    exit 1
fi

#======================= Deploy =======================

# convert INT and TERM signals to EXIT 1 by default
trap "exit 1" INT TERM
# kill whole processgroup on exit
trap "/bin/kill -- -$$" EXIT

for ansible_command_id in "${!ansible_commands[@]}"; do
   ansible_command=${ansible_commands[$ansible_command_id]}
   echo "Launching $ansible_command"
   eval $ansible_command
   ansible_pids[$!]="$ansible_command"
done

while (( ${#ansible_pids[@]} )); do
  for pid in "${!ansible_pids[@]}"; do
    command=${ansible_pids[$pid]}
    echo "checking pid: $pid command: [ $command ]"
    if ! kill -0 "$pid" 2>/dev/null; then # kill -0 checks for process existance
      # we know this pid has exited; retrieve its exit status
      wait "$pid"
      ret_val=$?
      echo "$pid [ $command ] exit code $ret_val"
      unset "ansible_pids[$pid]"
      if [ $ret_val -ne 0 ]; then
          # set exit code when a process finishes with anything other than 0
          trap "exit $ret_val" INT TERM
          exit
      fi
    fi
  done
  sleep 1
done

# Reset traps
trap "" INT TERM
trap "" EXIT

#======================================================

# if we made it this far all processes exited 0
#trap "exit 0" INT TERM
exit
