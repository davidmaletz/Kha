package kha;

import haxe.io.Bytes;
import haxe.io.BytesData;
import kha.kore.graphics4.TextureUnit;
import kha.graphics4.TextureFormat;
import kha.graphics4.DepthStencilFormat;
import kha.graphics4.Usage;

@:headerCode("
#include <kinc/graphics4/rendertarget.h>
#include <kinc/graphics4/texture.h>
#include <kinc/graphics4/texturearray.h>
#include <kinc/video.h>

#include <assert.h>

enum KhaImageType {
	KhaImageTypeNone,
	KhaImageTypeTexture,
	KhaImageTypeRenderTarget,
	KhaImageTypeTextureArray
};
")
@:headerClassCode("
	KhaImageType imageType;
	int originalWidth;
	int originalHeight;
	uint8_t *imageData;
	bool ownsImageData;
	kinc_g4_texture_t texture;
	kinc_g4_render_target_t renderTarget;
	kinc_g4_texture_array_t textureArray;
")
class Image implements Canvas implements Resource {
   	@:keep public static var count:Int = 0;
	var myFormat: TextureFormat;
	var readable: Bool;
	public var hasMipmaps:Bool = false;
    	private var byteSize:Int = 0;

	var graphics1: kha.graphics1.Graphics;
	var graphics2: kha.graphics2.Graphics;
	var graphics4: kha.graphics4.Graphics;

	public static function fromVideo(video: Video): Image {
		var image = new Image(false, false);
		image.myFormat = RGBA32;
		image.initVideo(cast(video, kha.kore.Video));
		image.byteSize = image.width*image.height*formatByteSize(image.myFormat); SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	public static function create(width: Int, height: Int, format: TextureFormat = null, usage: Usage = null, readable: Bool = false): Image {
		return _create2(width, height, format == null ? TextureFormat.RGBA32 : format, readable, false, NoDepthAndStencil, 0);
	}

	public static function create3D(width: Int, height: Int, depth: Int, format: TextureFormat = null, usage: Usage = null, readable: Bool = false): Image {
		return _create3(width, height, depth, format == null ? TextureFormat.RGBA32 : format, readable, 0);
	}

	public static function createRenderTarget(width: Int, height: Int, format: TextureFormat = null, depthStencil: DepthStencilFormat = NoDepthAndStencil,
			antiAliasingSamples: Int = 1): Image {
		return _create2(width, height, format == null ? TextureFormat.RGBA32 : format, false, true, depthStencil, antiAliasingSamples);
	}

	/**
	 * The provided images need to be readable.
	 */
	public static function createArray(images: Array<Image>, format: TextureFormat = null): Image {
		var image = new Image(false);
		image.myFormat = (format == null) ? TextureFormat.RGBA32 : format;
		image.initArrayTexture(images);
		image.byteSize = images[0].byteSize*images.length; SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	@:functionCode("
		kinc_image_t *kincImages = (kinc_image_t*)malloc(sizeof(kinc_image_t) * images->length);
		for (unsigned i = 0; i < images->length; ++i) {
			kinc_image_init(&kincImages[i], images->__get(i).StaticCast<::kha::Image>()->imageData, images->__get(i).StaticCast<::kha::Image>()->originalWidth, images->__get(i).StaticCast<::kha::Image>()->originalHeight, (kinc_image_format_t)getTextureFormat(images->__get(i).StaticCast<::kha::Image>()->myFormat));
		}
		kinc_g4_texture_array_init(&textureArray, kincImages, images->length);
		for (unsigned i = 0; i < images->length; ++i) {
			kinc_image_destroy(&kincImages[i]);
		}
		free(kincImages);
		imageType = KhaImageTypeTextureArray;
		originalWidth = images->__get(0).StaticCast<::kha::Image>()->originalWidth;
		originalHeight = images->__get(0).StaticCast<::kha::Image>()->originalHeight;
	")
	function initArrayTexture(images: Array<Image>): Void {}

	public static function fromBytes(bytes: Bytes, width: Int, height: Int, format: TextureFormat = null, usage: Usage = null, readable: Bool = false): Image {
		var image = new Image(readable);
		image.myFormat = format;
		image.initFromBytes(bytes.getData(), width, height, getTextureFormat(format));
		image.byteSize = width*height*formatByteSize(format); SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	@:functionCode("
		kinc_image_t image;
		kinc_image_init(&image, bytes.GetPtr()->GetBase(), width, height, (kinc_image_format_t)format);
		kinc_g4_texture_init_from_image(&texture, &image);
		if (readable) {
			imageData = (uint8_t*)image.data;
		}
		kinc_image_destroy(&image);
		imageType = KhaImageTypeTexture;
		originalWidth = width;
		originalHeight = height;
	")
	function initFromBytes(bytes: BytesData, width: Int, height: Int, format: Int): Void {count++;}

	public static function fromBytes3D(bytes: Bytes, width: Int, height: Int, depth: Int, format: TextureFormat = null, usage: Usage = null,
			readable: Bool = false): Image {
		var image = new Image(readable);
		image.myFormat = format;
		image.initFromBytes3D(bytes.getData(), width, height, depth, getTextureFormat(format));
		image.byteSize = width*height*depth*formatByteSize(format); SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	@:functionCode("
		kinc_image_t image;
		kinc_image_init3d(&image, bytes.GetPtr()->GetBase(), width, height, depth, (kinc_image_format_t)format);
		kinc_g4_texture_init_from_image3d(&texture, &image);
		if (readable) {
			imageData = (uint8_t*)image.data;
		}
		kinc_image_destroy(&image);
		imageType = KhaImageTypeTexture;
		originalWidth = width;
		originalHeight = height;
	")
	function initFromBytes3D(bytes: BytesData, width: Int, height: Int, depth: Int, format: Int): Void {count++;}

	public static function fromEncodedBytes(bytes: Bytes, format: String, doneCallback: Image->Void, errorCallback: String->Void,
			readable: Bool = false): Void {
		var image = new Image(readable);
		var isFloat = format == "hdr" || format == "HDR";
		image.myFormat = isFloat ? TextureFormat.RGBA128 : TextureFormat.RGBA32;
		image.initFromEncodedBytes(bytes.getData(), format);
		image.byteSize = image.width*image.height*formatByteSize(image.myFormat); SystemImpl.graphicsBytes += image.byteSize;
		doneCallback(image);
	}

	@:functionCode("
		size_t size = kinc_image_size_from_encoded_bytes(bytes.GetPtr()->GetBase(), bytes.GetPtr()->length, format.c_str());
		void* data = malloc(size);
		kinc_image_t image;
		kinc_image_init_from_encoded_bytes(&image, data, bytes.GetPtr()->GetBase(), bytes.GetPtr()->length, format.c_str());
		originalWidth = image.width;
		originalHeight = image.height;
		kinc_g4_texture_init_from_image(&texture, &image);
		if (readable) {
			imageData = (uint8_t*)image.data;
		}
		kinc_image_destroy(&image);
		if (!readable) {
			free(data);
		}
		imageType = KhaImageTypeTexture;
	")
	function initFromEncodedBytes(bytes: BytesData, format: String): Void {count++;}

	function new(readable: Bool, ?dispose = true) {
		this.readable = readable;
		nullify();

		if (dispose) {
			cpp.vm.Gc.setFinalizer(this, cpp.Function.fromStaticFunction(finalize));
		}
	}

	@:functionCode("
		imageType = KhaImageTypeNone;
		originalWidth = 0;
		originalHeight = 0;
		imageData = NULL;
		ownsImageData = false;
	")
	function nullify() {}

	@:functionCode("
		if (image->imageType != KhaImageTypeNone) {
			image->unload();
		}
	")
	@:void static function finalize(image: Image): Void {}

	static function getRenderTargetFormat(format: TextureFormat): Int {
		switch (format) {
			case RGBA32: // Target32Bit
				return 0;
			case RGBA64: // Target64BitFloat
				return 1;
			case A32: // Target32BitRedFloat
				return 2;
			case RGBA128: // Target128BitFloat
				return 3;
			case DEPTH16: // Target16BitDepth
				return 4;
			case L8:
				return 5; // Target8BitRed
			case A16:
				return 6; // Target16BitRedFloat
			default:
				return 0;
		}
	}

	static function getDepthBufferBits(depthAndStencil: DepthStencilFormat): Int {
		return switch (depthAndStencil) {
			case NoDepthAndStencil: -1;
			case DepthOnly: 24;
			case DepthAutoStencilAuto: 24;
			case Depth24Stencil8: 24;
			case Depth32Stencil8: 32;
			case Depth16: 16;
		}
	}

	static function getStencilBufferBits(depthAndStencil: DepthStencilFormat): Int {
		return switch (depthAndStencil) {
			case NoDepthAndStencil: -1;
			case DepthOnly: -1;
			case DepthAutoStencilAuto: 8;
			case Depth24Stencil8: 8;
			case Depth32Stencil8: 8;
			case Depth16: 0;
		}
	}

	static function getTextureFormat(format: TextureFormat): Int {
		switch (format) {
			case RGBA32:
				return 0;
			case RGBA128:
				return 3;
			case RGBA64:
				return 4;
			case A32:
				return 5;
			case A16:
				return 7;
			default:
				return 1; // Grey8
		}
	}

	@:noCompletion
	public static function _create2(width: Int, height: Int, format: TextureFormat, readable: Bool, renderTarget: Bool, depthStencil: DepthStencilFormat,
			samplesPerPixel: Int): Image {
		var image = new Image(readable);
		image.myFormat = format;
		if (renderTarget)
			image.initRenderTarget(width, height, getRenderTargetFormat(format), getDepthBufferBits(depthStencil), getStencilBufferBits(depthStencil),
				samplesPerPixel);
		else
			image.init(width, height, getTextureFormat(format));
        	image.byteSize = width*height*formatByteSize(format); SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	@:noCompletion
	public static function _create3(width: Int, height: Int, depth: Int, format: TextureFormat, readable: Bool, contextId: Int): Image {
		var image = new Image(readable);
		image.myFormat = format;
		image.init3D(width, height, depth, getTextureFormat(format));
		image.byteSize = width*height*depth*formatByteSize(format); SystemImpl.graphicsBytes += image.byteSize;
		return image;
	}

	@:functionCode("
		kinc_g4_render_target_init_with_multisampling(&renderTarget, width, height, (kinc_g4_render_target_format_t)format, depthBufferBits, stencilBufferBits, samplesPerPixel);
		imageType = KhaImageTypeRenderTarget;
		originalWidth = width;
		originalHeight = height;
	")
	function initRenderTarget(width: Int, height: Int, format: Int, depthBufferBits: Int, stencilBufferBits: Int, samplesPerPixel: Int): Void {count++;}

	@:functionCode("
		kinc_g4_texture_init(&texture, width, height, (kinc_image_format_t)format);
		imageType = KhaImageTypeTexture;
		originalWidth = width;
		originalHeight = height;
	")
	function init(width: Int, height: Int, format: Int): Void {count++;}

	@:functionCode("
		kinc_g4_texture_init3d(&texture, width, height, depth, (kinc_image_format_t)format);
		imageType = KhaImageTypeTexture;
		originalWidth = width;
		originalHeight = height;
	")
	function init3D(width: Int, height: Int, depth: Int, format: Int): Void {count++;}

	@:functionCode("
		texture = *kinc_video_current_image(&video->video);
		imageType = KhaImageTypeTexture;
	")
	function initVideo(video: kha.kore.Video): Void {}

	public static function createEmpty(readable: Bool, floatFormat: Bool): Image {
		var image = new Image(readable);
		image.myFormat = floatFormat ? TextureFormat.RGBA128 : TextureFormat.RGBA32;
		return image;
	}

	/*public static function fromFile(filename: String, readable: Bool): Image {
			var image = new Image(readable);
			var isFloat = StringTools.endsWith(filename, ".hdr");
			image.format = isFloat ? TextureFormat.RGBA128 : TextureFormat.RGBA32;
			image.initFromFile(filename);
			return image;
		}

		@:functionCode('texture = new Kore::Graphics4::Texture(filename.c_str(), readable);')
		private function initFromFile(filename: String): Void {

	}*/
	public var g1(get, never): kha.graphics1.Graphics;

	function get_g1(): kha.graphics1.Graphics {
		if (graphics1 == null) {
			graphics1 = new kha.graphics2.Graphics1(this);
		}
		return graphics1;
	}

	public var g2(get, never): kha.graphics2.Graphics;

	function get_g2(): kha.graphics2.Graphics {
		if (graphics2 == null) {
			graphics2 = new kha.kore.graphics4.Graphics2(this);
		}
		return graphics2;
	}

	public var g4(get, never): kha.graphics4.Graphics;

	function get_g4(): kha.graphics4.Graphics {
		if (graphics4 == null) {
			graphics4 = new kha.kore.graphics4.Graphics(this);
		}
		return graphics4;
	}

	public static var maxSize(get, never): Int;

	static function get_maxSize(): Int {
		return 4096;
	}

	public static var nonPow2Supported(get, never): Bool;

	@:functionCode("return kinc_g4_supports_non_pow2_textures();")
	static function get_nonPow2Supported(): Bool {
		return false;
	}

	@:functionCode("return kinc_g4_render_targets_inverted_y();")
	public static function renderTargetsInvertedY(): Bool {
		return false;
	}

	public var width(get, never): Int;

	@:functionCode("return originalWidth;")
	function get_width(): Int {
		return 0;
	}

	public var height(get, never): Int;

	@:functionCode("return originalHeight;")
	function get_height(): Int {
		return 0;
	}

	public var depth(get, never): Int;

	@:functionCode("if (imageType == KhaImageTypeTexture) return texture.tex_depth; else return 0;")
	function get_depth(): Int {
		return 0;
	}

	public var format(get, never): TextureFormat;

	@:functionCode("if (imageType == KhaImageTypeTexture) return texture.format; else return 0;")
	function get_format(): TextureFormat {
		return TextureFormat.RGBA32;
	}

	public var realWidth(get, never): Int;

	@:functionCode("if (imageType == KhaImageTypeTexture) return texture.tex_width; else if (imageType == KhaImageTypeRenderTarget) return renderTarget.width; else return 0;")
	function get_realWidth(): Int {
		return 0;
	}

	public var realHeight(get, never): Int;

	@:functionCode("if (imageType == KhaImageTypeTexture) return texture.tex_height; else if (imageType == KhaImageTypeRenderTarget) return renderTarget.height; else return 0;")
	function get_realHeight(): Int {
		return 0;
	}

	public function isOpaque(x: Int, y: Int): Bool {
		return isOpaqueInternal(x, y, getTextureFormat(myFormat));
	}

	@:functionCode("
		kinc_image_t image;
		kinc_image_init(&image, imageData, originalWidth, originalHeight, (kinc_image_format_t)format);
		bool opaque = (kinc_image_at(&image, x, y) & 0xff) != 0;
		kinc_image_destroy(&image);
		return opaque;
	")
	function isOpaqueInternal(x: Int, y: Int, format: Int): Bool {
		return true;
	}

	public inline function at(x: Int, y: Int): Color {
		return Color.fromValue(atInternal(x, y, getTextureFormat(myFormat)));
	}

	@:functionCode("
		kinc_image_t image;
		kinc_image_init(&image, imageData, originalWidth, originalHeight, (kinc_image_format_t)format);
		int value = kinc_image_at(&image, x, y);
		kinc_image_destroy(&image);
		return value;
	")
	function atInternal(x: Int, y: Int, format: Int): Int {
		return 0;
	}

	@:keep
	@:functionCode("
		if (imageType == KhaImageTypeTexture) {
			kinc_g4_texture_destroy(&texture); ::kha::Image_obj::count--;
		}
		else if (imageType == KhaImageTypeRenderTarget) {
			kinc_g4_render_target_destroy(&renderTarget); ::kha::Image_obj::count--;
		}
		else if (imageType == KhaImageTypeTextureArray) {
			kinc_g4_texture_array_destroy(&textureArray); ::kha::Image_obj::count--;
		}
		else {
			assert(false);
		}
		if (ownsImageData) {
			free(imageData);
		}
		imageData = NULL;
		imageType = KhaImageTypeNone;
	")
    	public function unload(): Void {SystemImpl.graphicsBytes -= byteSize; byteSize = 0; bytes = null;}

	var bytes: Bytes = null;

	@:functionCode("
		if(::hx::IsNull(this->bytes)){
		    int size = kinc_image_format_sizeof(texture.format) * originalWidth * originalHeight;
		    if(texture.tex_depth > 1) size *= texture.tex_depth;
		    this->bytes = ::haxe::io::Bytes_obj::alloc(size);
		} return this->bytes;
	")
	public function lock(level: Int = 0): Bytes {
		return null;
	}

	@:functionCode("
		uint8_t *b = bytes->b->Pointer();
		uint8_t *tex = kinc_g4_texture_lock(&texture);
		int size = kinc_image_format_sizeof(texture.format);
		int stride = kinc_g4_texture_stride(&texture);
		int slice = kinc_g4_texture_slice(&texture);
		int depth = texture.tex_depth; if(depth < 1) depth = 1;
		for (int z = 0; z < depth; ++z)
		for (int y = 0; y < texture.tex_height; ++y) {
            		int zy = (z*originalHeight+y) * originalWidth, lineOff = z * slice + y * stride;
			for (int x = 0; x < texture.tex_width; ++x) {
#ifdef KORE_DIRECT3D
				if (texture.format == KINC_IMAGE_FORMAT_RGBA32) {
					//RBGA->BGRA
				        tex[lineOff + x * size + 0] = b[(zy + x) * size + 2];
				        tex[lineOff + x * size + 1] = b[(zy + x) * size + 1];
				        tex[lineOff + x * size + 2] = b[(zy + x) * size + 0];
				        tex[lineOff + x * size + 3] = b[(zy + x) * size + 3];
				}
				else
#endif
				{
					for (int i = 0; i < size; ++i) {
			                        tex[lineOff + x * size + i] = b[(zy + x) * size + i];
					}
				}
			}
		}
		kinc_g4_texture_unlock(&texture);
	")
	public function unlock(): Void {
	}

	@:ifFeature("kha.Image.getPixelsInternal")
	var pixels: Bytes = null;
	@:ifFeature("kha.Image.getPixelsInternal")
	var pixelsAllocated: Bool = false;

	@:functionCode("
		if (imageType != KhaImageTypeRenderTarget) return NULL;
		if (!this->pixelsAllocated) {
			int size = formatSize * renderTarget.width * renderTarget.height;
			this->pixels = ::haxe::io::Bytes_obj::alloc(size);
			this->pixelsAllocated = true;
		}
		uint8_t *b = this->pixels->b->Pointer();
		kinc_g4_render_target_get_pixels(&renderTarget, b);
		return this->pixels;
	")
	function getPixelsInternal(formatSize: Int): Bytes {
		return null;
	}

	public function getPixels(): Bytes {
		return getPixelsInternal(formatByteSize(myFormat));
	}

	static function formatByteSize(format: TextureFormat): Int {
		return switch (format) {
			case RGBA32: 4;
			case L8: 1;
			case RGBA128: 16;
			case DEPTH16: 2;
			case RGBA64: 8;
			case A32: 4;
			case A16: 2;
			default: 4;
		}
	}

	public function generateMipmaps(levels: Int): Void {
		hasMipmaps = true; untyped __cpp__("if (imageType == KhaImageTypeTexture) kinc_g4_texture_generate_mipmaps(&texture, levels); else if (imageType == KhaImageTypeRenderTarget) kinc_g4_render_target_generate_mipmaps(&renderTarget, levels)");
	}

	public function setMipmaps(mipmaps: Array<Image>): Void {
		hasMipmaps = true; for (i in 0...mipmaps.length) {
			var khaImage = mipmaps[i];
			var level = i + 1;
			var format = getTextureFormat(this.format);
			untyped __cpp__("
				kinc_image_t image;
				kinc_image_init(&image, {0}->imageData, {0}->originalWidth, {0}->originalHeight, (kinc_image_format_t){2});
				kinc_g4_texture_set_mipmap(&texture, &image, {1});
				kinc_image_destroy(&image);
			", khaImage, level, format);
		}
	}

	public function setDepthStencilFrom(image: Image): Void {
		untyped __cpp__("kinc_g4_render_target_set_depth_stencil_from(&renderTarget, &image->renderTarget)");
	}

	@:functionCode("if (imageType == KhaImageTypeTexture) kinc_g4_texture_clear(&texture, x, y, z, width, height, depth, color);")
	public function clear(x: Int, y: Int, z: Int, width: Int, height: Int, depth: Int, color: Color): Void {}

	public var stride(get, never): Int;

	@:functionCode("return kinc_g4_texture_stride(&texture);")
	function get_stride(): Int {
		return 0;
	}
}
