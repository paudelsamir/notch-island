// Copy to ~/.config/opencode/plugin/notch-island.js
// Pushes opencode agent events to the notch through scripts/opencode-hook.sh.
const HOOK = `${process.env.HOME}/.config/omarchy/plugins/user.notch-island/scripts/opencode-hook.sh`

export const NotchIsland = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      const sid = event.properties?.sessionID ?? ""
      if (event.type === "session.idle") {
        await $`${HOOK} ${"opencode finished"} ${"The agent is waiting for you"} ${sid}`.quiet().nothrow()
      }
      if (event.type === "session.error") {
        await $`${HOOK} ${"opencode error"} ${"The agent hit an error"} ${sid}`.quiet().nothrow()
      }
      if (event.type === "permission.updated") {
        await $`${HOOK} ${"opencode needs permission"} ${"Approve or deny in the terminal"} ${sid}`.quiet().nothrow()
      }
    },
  }
}
