import { createRouter, createWebHistory } from 'vue-router'

import Home from './pages/Home.vue'
import Configure from './pages/Configure.vue'
import Pair from './pages/Pair.vue'
import Executor from './pages/Executor.vue'
import Activity from './pages/Activity.vue'

const routes = [
  { path: '/', name: 'home', component: Home },
  { path: '/configure', name: 'configure', component: Configure },
  { path: '/pair', name: 'pair', component: Pair },
  { path: '/activity', name: 'activity', component: Activity },
  { path: '/executor', name: 'executor', component: Executor },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() { return { top: 0 } },
})

export default router
