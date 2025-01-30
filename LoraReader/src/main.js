import { createApp } from 'vue'
import App from './App.vue'
import { updateLoraData, initializeAllLoras, initGlobalState, globalState } from './utils/globalVar'

const app = createApp(App)

// 初始化应用数据
async function initializeApplication() {
    try {
        // 初始化全局状态
        initGlobalState()
        
        // 初始化全局 LoRA 数据
        await initializeAllLoras()
        
        // 初始化当前页面数据
        const response = await fetch('http://localhost:5000/lora-files?path=/')
        if (response.ok) {
            const data = await response.json()
            if (!data.error) {
                updateLoraData(data.lora_files)
            }
        }
    } catch (err) {
        console.error('Error initializing application:', err)
    }
}

// 启动应用前初始化数据
initializeApplication().then(() => {
    app.mount('#app')
})
