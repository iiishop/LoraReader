from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import logging
import subprocess
import sys
import os
import json
import re
from safetensors import safe_open

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

CONFIG_PATH = os.path.join(os.path.dirname(
    os.path.abspath(__file__)), 'config.json')


def load_config():
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
        return {"lora_path": ""}
    except Exception as e:
        logger.error(f"Error loading config: {e}")
        return {"lora_path": ""}


def save_config(config):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4)


@app.route('/config', methods=['GET'])
def get_config():
    return jsonify(load_config())


@app.route('/config', methods=['POST'])
def update_config():
    try:
        config = load_config()
        new_config = request.json
        config.update(new_config)
        save_config(config)
        return jsonify({"status": "success"})
    except Exception as e:
        logger.error(f"Error updating config: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/select-folder', methods=['GET'])
def select_folder():
    try:
        # 获取当前脚本所在目录
        current_dir = os.path.dirname(os.path.abspath(__file__))
        dialog_script = os.path.join(current_dir, 'folder_dialog.py')

        # 调用对话框脚本并获取输出
        result = subprocess.run([sys.executable, dialog_script],
                                capture_output=True,
                                text=True)

        folder_path = result.stdout.strip()
        logger.info(f"Selected folder: {folder_path}")

        return jsonify({'path': folder_path})
    except Exception as e:
        logger.error(f"Error selecting folder: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/folders', methods=['GET'])
def get_folders():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '')

        if not base_path or not os.path.exists(base_path):
            return jsonify({'error': 'Invalid base path'}), 404

        current_path = os.path.join(base_path, sub_path)
        if not os.path.exists(current_path):
            return jsonify({'error': 'Path not found'}), 404

        # 确保不会访问基础路径以外的目录
        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        folders = [d for d in os.listdir(current_path)
                   if os.path.isdir(os.path.join(current_path, d))]

        return jsonify({
            'folders': folders,
            'current_path': sub_path or '/',
            'can_go_back': bool(sub_path)
        })
    except Exception as e:
        logger.error(f"Error scanning folders: {e}")
        return jsonify({'error': str(e)}), 500


def get_lora_metadata(file_path):
    try:
        with safe_open(file_path, framework="pt") as f:
            metadata = f.metadata()
            return {
                'ss_base_model_version': metadata.get('ss_base_model_version', 'Unknown'),
                'ss_network_module': metadata.get('ss_network_module', ''),
                'ss_network_dim': metadata.get('ss_network_dim', ''),
                'ss_network_alpha': metadata.get('ss_network_alpha', '')
            }
    except Exception as e:
        logger.error(f"Error reading safetensors metadata: {e}")
        return {}


def get_lora_config(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
            return {
                'activation_text': config.get('activation text', ''),
                'preferred_weight': config.get('preferred weight', 0),
                'notes': config.get('notes', ''),
                'description': config.get('description', '')
            }
    except Exception as e:
        logger.error(f"Error reading lora config: {e}")
        return {}


@app.route('/lora-files', methods=['GET'])
def get_lora_files():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '').strip('/')  # 修改这里

        if not base_path or not os.path.exists(base_path):
            return jsonify({'error': 'Invalid base path'}), 404

        current_path = os.path.normpath(os.path.join(base_path, sub_path))
        if not os.path.exists(current_path):
            return jsonify({'error': 'Path not found'}), 404

        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        lora_files = []
        files = os.listdir(current_path)

        for file in files:
            if file.endswith('.safetensors'):
                base_name = file[:-11]
                full_path = os.path.join(current_path, file)

                # 获取 metadata
                metadata = get_lora_metadata(full_path)

                # 检查相关文件
                preview_file = next((f for f in files if f.startswith(
                    base_name) and f.endswith('.png')), None)
                config_file = next((f for f in files if f.startswith(
                    base_name) and f.endswith('.json')), None)

                # 获取配置文件内容
                config_data = {}
                if config_file:
                    config_path = os.path.join(current_path, config_file)
                    config_data = get_lora_config(config_path)

                lora_info = {
                    'name': file,
                    'base_name': base_name,
                    'has_preview': bool(preview_file),
                    'has_config': bool(config_file),
                    'preview_path': f'/preview?path={sub_path}&file={preview_file}' if preview_file else None,
                    'metadata': metadata,
                    'config': config_data  # 添加配置数据
                }
                lora_files.append(lora_info)

        return jsonify({
            'lora_files': lora_files,
            'current_path': sub_path or '/'
        })

    except Exception as e:
        logger.error(f"Error scanning lora files: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/preview', methods=['GET'])
def get_preview():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '')
        file_name = request.args.get('file', '')

        if not all([base_path, file_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        file_path = os.path.join(base_path, sub_path, file_name)

        if not os.path.exists(file_path):
            return jsonify({'error': 'File not found'}), 404

        return send_file(file_path, mimetype='image/png')

    except Exception as e:
        logger.error(f"Error sending preview: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/previews', methods=['GET'])
def get_previews():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        lora_name = request.args.get('name', '')
        sub_path = request.args.get('path', '')

        if not all([base_path, lora_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        
        # 获取当前目录下所有文件
        files = os.listdir(current_path)
        
        # 找出所有匹配的预览图
        preview_pattern = re.compile(f'^{re.escape(lora_name)}(_\\d+)?\\.png$')
        previews = [f'/preview?path={sub_path}&file={f}' for f in files if preview_pattern.match(f)]
        
        return jsonify({'previews': sorted(previews)})

    except Exception as e:
        logger.error(f"Error getting previews: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/upload-preview', methods=['POST'])
def upload_preview():
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['file']
        lora_name = request.form.get('lora_name')
        sub_path = request.form.get('path', '').strip('/')

        if not file or not lora_name:
            return jsonify({'error': 'Invalid parameters'}), 400

        config = load_config()
        base_path = config.get('lora_path', '')
        
        # 构造完整的目标目录路径
        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        
        # 确保目标目录存在且在base_path下
        if not os.path.exists(current_path):
            return jsonify({'error': 'Target directory not found'}), 404
            
        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        # 获取当前目录下现有的预览图数量
        files = os.listdir(current_path)
        preview_pattern = re.compile(f'^{re.escape(lora_name)}_\\d+\\.png$')
        existing_previews = [f for f in files if preview_pattern.match(f)]
        next_number = len(existing_previews) + 1

        # 构造新文件名
        new_filename = f'{lora_name}_{next_number}.png'
        file_path = os.path.join(current_path, new_filename)
        
        logger.info(f"Saving preview to: {file_path}")
        file.save(file_path)

        return jsonify({
            'status': 'success',
            'filename': new_filename,
            'path': sub_path
        })

    except Exception as e:
        logger.error(f"Error uploading preview: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/update-config', methods=['POST'])
def update_lora_config():
    try:
        data = request.json
        base_path = load_config().get('lora_path', '')
        sub_path = data.get('path', '').strip('/')
        lora_name = data.get('lora_name', '')
        config = data.get('config', {})

        if not all([base_path, lora_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        # 构建配置文件路径
        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        config_filename = f"{lora_name}.json"
        config_path = os.path.join(current_path, config_filename)

        # 准备新的配置数据
        config_data = {
            'activation text': config.get('activation_text', ''),
            'preferred weight': config.get('preferred_weight', 0),
            'notes': config.get('notes', ''),
            'description': config.get('description', '')
        }

        # 写入文件
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, indent=4, ensure_ascii=False)

        return jsonify({'status': 'success'})

    except Exception as e:
        logger.error(f"Error updating lora config: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    try:
        logger.info("Starting Flask server...")        
        app.run(debug=True, port=5000)    
    except Exception as e:        
        logger.error(f"Server error: {e}")
        input("Press Enter to exit...")
