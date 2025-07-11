#!/usr/bin/env python3
import json
import os
import sys

def extract_screenshots(json_file_path, output_dir):
    """Extract screenshots from Flutter integration test JSON data."""
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        with open(json_file_path, 'r') as f:
            data = json.load(f)
        
        screenshots = data.get('screenshots', [])
        print(f"Found {len(screenshots)} screenshots")
        
        for screenshot in screenshots:
            name = screenshot.get('screenshotName', 'unknown')
            bytes_data = screenshot.get('bytes', [])
            
            if bytes_data:
                output_path = os.path.join(output_dir, f"{name}.png")
                
                # Convert bytes array to binary data
                binary_data = bytes(bytes_data)
                
                # Write PNG file
                with open(output_path, 'wb') as png_file:
                    png_file.write(binary_data)
                
                print(f"✓ Extracted: {name}.png ({len(binary_data)} bytes)")
            else:
                print(f"✗ No data for: {name}")
        
        return len(screenshots)
        
    except FileNotFoundError:
        print(f"Error: File not found: {json_file_path}")
        return 0
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in file: {json_file_path}")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 0

if __name__ == "__main__":
    # Default paths
    json_file = "build/integration_response_data.json"
    output_dir = "assets/screenshots"
    
    # Override with command line arguments if provided
    if len(sys.argv) > 1:
        json_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    
    print("🎨 Extracting screenshots from integration test data")
    print(f"Input file: {json_file}")
    print(f"Output directory: {output_dir}")
    print("-" * 50)
    
    extracted = extract_screenshots(json_file, output_dir)
    
    if extracted > 0:
        print("-" * 50)
        print(f"✅ Successfully extracted {extracted} screenshots!")
        print(f"📁 Screenshots saved to: {output_dir}")
    else:
        print("❌ No screenshots were extracted.")
        sys.exit(1)
