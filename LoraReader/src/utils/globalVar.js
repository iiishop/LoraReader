import { ref } from 'vue'

// 当前页面的 LoRA 映射
export const globalLoraMap = ref(new Map())
export const loraNameMap = ref(new Map())

// 全局所有 LoRA 的映射
export const allLoraMap = ref(new Map())
export const allLoraNameMap = ref(new Map())

// 更新当前页面的 LoRA 数据
export function updateLoraData(loraFiles) {
    globalLoraMap.value.clear()
    loraNameMap.value.clear()
    
    loraFiles.forEach(lora => {
        globalLoraMap.value.set(lora.name, lora)
        const baseName = lora.name.replace('.safetensors', '')
        const mainName = baseName.replace(/-\d+$/, '')
        loraNameMap.value.set(baseName, lora)
        loraNameMap.value.set(mainName, lora)
    })
}

// 初始化全局 LoRA 数据
export async function initializeAllLoras() {
    try {
        const response = await fetch('http://localhost:5000/scan-all-loras')
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        
        allLoraMap.value.clear()
        allLoraNameMap.value.clear()

        data.lora_files.forEach(lora => {
            allLoraMap.value.set(lora.name, lora)
            const baseName = lora.name.replace('.safetensors', '')
            const mainName = baseName.replace(/-\d+$/, '')
            allLoraNameMap.value.set(baseName, lora)
            allLoraNameMap.value.set(mainName, lora)
        })
        
        console.log(`Initialized ${allLoraMap.value.size} global LoRAs`)
        return true
    } catch (err) {
        console.error('Error initializing all LoRAs:', err)
        return false
    }
}

// 修改查找函数使用全局映射
export function findLoraByName(name) {
    console.log('Finding LoRA by name:', name)
    
    const cleanName = name.toLowerCase()
        .replace(/\.safetensors$/, '')
        .replace(/^(?:lora|lyco)_/, '')  // 移除 lora_ 或 lyco_ 前缀
        .replace(/<[^>]*>/g, '')
        .trim()
    
    console.log('Cleaned name:', cleanName)
    
    // 首先在全局映射中查找
    let lora = allLoraNameMap.value.get(cleanName)
    if (lora) {
        console.log('Found in global map')
        return lora
    }
    
    // 在全局映射中进行模糊匹配
    for (const [key, value] of allLoraNameMap.value.entries()) {
        const cleanKey = key.toLowerCase()
        if (cleanKey.includes(cleanName) || cleanName.includes(cleanKey)) {
            console.log('Found by fuzzy match in global map:', key)
            return value
        }
    }
    
    console.log('No LoRA found')
    return null
}

export function getAllLoras() {
    return Array.from(globalLoraMap.value.values())
}

// 添加全局状态管理
export const globalState = {
    loraDetailStack: ref([]),
    imageDetailStack: ref([]), // 新增图片详情栈

    openLoraDetail(lora) {
        const baseZIndex = 1000;
        const stackLength = this.loraDetailStack.value.length + this.imageDetailStack.value.length;
        this.loraDetailStack.value.push({
            lora,
            zIndex: baseZIndex + stackLength * 2 // 使用2的倍数，确保新的详情面板总是在当前层级之上
        });
    },

    closeLoraDetail(index = -1) {
        if (index === -1) {
            this.loraDetailStack.value.pop();
        } else {
            this.loraDetailStack.value.splice(index, 1);
        }
    },

    openImageDetail(imageUrl) {
        const baseZIndex = 1000;
        const stackLength = this.loraDetailStack.value.length + this.imageDetailStack.value.length;
        this.imageDetailStack.value.push({
            imageUrl,
            zIndex: baseZIndex + stackLength * 2 + 1 // 使用奇数，确保在最近的 LoraDetail 之上
        });
    },

    closeImageDetail(index = -1) {
        if (index === -1) {
            this.imageDetailStack.value.pop();
        } else {
            this.imageDetailStack.value.splice(index, 1);
        }
    }
};

// 初始化检查函数
export function initGlobalState() {
    if (!globalState.loraDetailStack.value) {
        globalState.loraDetailStack.value = [];
    }
    if (!globalState.imageDetailStack.value) {
        globalState.imageDetailStack.value = [];
    }
}
