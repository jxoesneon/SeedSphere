import { createRouter, createWebHistory } from 'vue-router'

import Home from './pages/Home.vue'
import Executor from './pages/Executor.vue'
import Start from './pages/Start.vue'
import Privacy from './pages/Privacy.vue'
import Terms from './pages/Terms.vue'
import Account from './pages/Account.vue'
import { auth } from './lib/auth'
import Configure from './pages/Configure.vue'
import Admin from './pages/Admin.vue'
import Forbidden from './pages/Forbidden.vue'
import Gardener from './pages/Gardener.vue'

const routes = [
  { path: '/', name: 'home', component: Home },
  { path: '/start', name: 'start', component: Start },
  { path: '/privacy', name: 'privacy', component: Privacy },
  { path: '/terms', name: 'terms', component: Terms },
  { path: '/account', name: 'account', component: Account, meta: { requiresAuth: true } },
  { path: '/executor', name: 'executor', component: Executor },
  { path: '/configure', name: 'configure', component: Configure },
  { path: '/gardener', name: 'gardener', component: Gardener, meta: { requiresAuth: true } },
  // Per-seedling Configure route (renders the same Configure page, keeps dynamic path intact)
  {
    path: '/s/:seedling_id/:sk/configure',
    name: 'seedling-configure',
    component: Configure,
    meta: { requiresAuth: true },
    // Verify the current session owns this seedling before allowing entry
    async beforeEnter(to) {
      try {
        const sid = String(to.params?.seedling_id || '').trim()
        const sk = String(to.params?.sk || '').trim()
        if (!sid) return { name: 'home' }
        const q = sk ? `?sk=${encodeURIComponent(sk)}` : ''
        const r = await fetch(`/api/seedlings/${encodeURIComponent(sid)}/owner${q}`, { credentials: 'include' })
        if (r.status === 401) return { name: 'start', query: { return: to.fullPath, sid, sk } }
        if (r.status === 403) return { name: 'forbidden', query: { return: to.fullPath, sid, sk, reason: 'owned' } }
        if (!r.ok) return { name: 'home' }
        const j = await r.json().catch(() => ({ ok: false }))
        if (!j || !j.ok) return { name: 'home' }
        return true
      } catch (_) { return { name: 'home' } }
    },
  },
  { path: '/admin', name: 'admin', component: Admin, meta: { requiresAdmin: true } },
  { path: '/forbidden', name: 'forbidden', component: Forbidden },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() { return { top: 0 } },
})

// Global auth guard for routes that require authentication
router.beforeEach(async (to) => {
  if (to.meta && to.meta.requiresAuth) {
    if (!auth.state.user) {
      try { await auth.fetchSession() } catch (_) {}
    }
    if (!auth.state.user) {
      return { name: 'start', query: { return: to.fullPath } }
    }
  }
  if (to.meta && to.meta.requiresAdmin) {
    if (!auth.state.user) { try { await auth.fetchSession() } catch (_) {} }
    // Do not redirect; Admin.vue will render login/forbidden states client-side
  }
})

export default router
