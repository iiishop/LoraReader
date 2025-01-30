import { createApp } from 'vue'
import App from './App.vue'
import { updateLoraData } from './utils/globalVar'

const app = createApp(App)

// 初始化全局 Lora 数据
async function initGlobalLoras() {
    try {
        const response = await fetch('http://localhost:5000/lora-files?path=/')
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        if (!data.error) {
            updateLoraData(data.lora_files)
        }
    } catch (err) {
        console.error('Error initializing global loras:', err)
    }
}

// 启动应用前初始化数据
initGlobalLoras().then(() => {
    app.mount('#app')
})
