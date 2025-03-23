package com.example.performance_analysis

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Bitmap.CompressFormat
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class PoseDetectionPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var poseLandmarker: PoseLandmarker? = null
    private val scope = CoroutineScope(Dispatchers.Default)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "pose_detection_channel")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        poseLandmarker?.close()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeMediaPipe" -> initializeMediaPipe(result)
            "processWithMediaPipe" -> processWithMediaPipe(call, result)
            "calculateAdvancedMetrics" -> calculateAdvancedMetrics(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initializeMediaPipe(result: Result) {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_full.task")
                .build()

            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, options)
            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun processWithMediaPipe(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val imageData = call.argument<ByteArray>("imageData")
                    ?: throw IllegalArgumentException("Image data is required")
                val width = call.argument<Int>("width")
                    ?: throw IllegalArgumentException("Width is required")
                val height = call.argument<Int>("height")
                    ?: throw IllegalArgumentException("Height is required")
                val rotation = call.argument<Int>("rotation") ?: 0

                // Add logging for debugging
                println("Processing image: width=$width, height=$height, dataSize=${imageData.size}")

                // First try to decode as JPEG/PNG
                var bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
                if (bitmap == null) {
                    // If decoding fails, try to create bitmap from raw data
                    bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val buffer = ByteBuffer.wrap(imageData)
                    buffer.rewind() // Reset buffer position
                    bitmap.copyPixelsFromBuffer(buffer)
                }

                // Ensure bitmap dimensions match
                val scaledBitmap = if (bitmap.width != width || bitmap.height != height) {
                    Bitmap.createScaledBitmap(bitmap, width, height, true)
                } else {
                    bitmap
                }

                // Create MPImage using BitmapImageBuilder
                val mpImage = BitmapImageBuilder(scaledBitmap).build()
                
                val imageProcessingOptions = ImageProcessingOptions.builder()
                    .setRotationDegrees(rotation)
                    .build()

                val poseResult = poseLandmarker?.detect(mpImage, imageProcessingOptions)
                
                val processedResult = processLandmarkerResult(poseResult)
                result.success(processedResult)
                
                // Clean up bitmaps
                if (bitmap != scaledBitmap) {
                    bitmap.recycle()
                }
                scaledBitmap.recycle()
            } catch (e: Exception) {
                println("Error processing image: ${e.message}")
                e.printStackTrace()
                result.error("PROCESS_ERROR", e.message, null)
            }
        }
    }

    private fun calculateAdvancedMetrics(call: MethodCall, result: Result) {
        try {
            val motionData = call.arguments as Map<*, *>
            val metrics = mutableMapOf<String, Double>()

            // Calculate advanced metrics using MediaPipe's capabilities
            metrics["pose_quality"] = calculatePoseQuality(motionData)
            metrics["movement_fluidity"] = calculateMovementFluidity(motionData)
            metrics["balance_score"] = calculateBalanceScore(motionData)

            result.success(metrics)
        } catch (e: Exception) {
            result.error("METRICS_ERROR", e.message, null)
        }
    }

    private fun convertByteArrayToBitmap(data: ByteArray, width: Int, height: Int): Bitmap {
        try {
            // First try to decode as JPEG/PNG
            val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)
            if (bitmap != null) {
                return bitmap
            }
            
            // If decoding fails, try to create bitmap from raw data
            val bitmap2 = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap2.copyPixelsFromBuffer(ByteBuffer.wrap(data))
            return bitmap2
        } catch (e: Exception) {
            throw IllegalArgumentException("Failed to convert image data: ${e.message}")
        }
    }

    private fun processLandmarkerResult(result: PoseLandmarkerResult?): Map<String, Any> {
        if (result == null || result.landmarks().isEmpty()) return emptyMap()

        val landmarks = mutableMapOf<String, List<Double>>()
        result.landmarks().firstOrNull()?.forEachIndexed { index, landmark: NormalizedLandmark ->
            landmarks["landmark_$index"] = listOf(
                landmark.x().toDouble(),
                landmark.y().toDouble(),
                landmark.z().toDouble(),
                1.0  // Default confidence value
            )
        } ?: return emptyMap()  // Return empty map if no landmarks found

        return mapOf(
            "landmarks" to landmarks,
            "confidence" to (result.landmarks().firstOrNull()?.size?.toDouble() ?: 0.0)
        )
    }

    private fun calculatePoseQuality(motionData: Map<*, *>): Double {
        // Safely handle null values in pose quality calculation
        val joints = motionData["joints"] as? Map<*, *> ?: return 0.0
        var totalConfidence = 0.0
        var count = 0

        joints.forEach { (_, value) ->
            (value as? Map<*, *>)?.let { joint ->
                (joint["confidence"] as? Double)?.let { confidence ->
                    totalConfidence += confidence
                    count++
                }
            }
        }

        return if (count > 0) totalConfidence / count else 0.0
    }

    private fun calculateMovementFluidity(motionData: Map<*, *>): Double {
        // Safely handle null values in movement fluidity calculation
        val positions = motionData["jointPositions"] as? List<*> ?: return 0.0
        if (positions.size < 2) return 0.0

        var totalJerk = 0.0
        var validMeasurements = 0

        for (i in 2 until positions.size) {
            try {
                val pos = positions[i] as? Map<*, *> ?: continue
                val prevPos = positions[i - 1] as? Map<*, *> ?: continue
                val prevPrevPos = positions[i - 2] as? Map<*, *> ?: continue

                val x = pos["x"] as? Double ?: continue
                val y = pos["y"] as? Double ?: continue
                val z = pos["z"] as? Double ?: continue
                val prevX = prevPos["x"] as? Double ?: continue
                val prevY = prevPos["y"] as? Double ?: continue
                val prevZ = prevPos["z"] as? Double ?: continue
                val prevPrevX = prevPrevPos["x"] as? Double ?: continue
                val prevPrevY = prevPrevPos["y"] as? Double ?: continue
                val prevPrevZ = prevPrevPos["z"] as? Double ?: continue

                val jerk = calculateJerk(x, y, z, prevX, prevY, prevZ, prevPrevX, prevPrevY, prevPrevZ)
                totalJerk += jerk
                validMeasurements++
            } catch (e: Exception) {
                continue
            }
        }

        return if (validMeasurements > 0) {
            1.0 - (totalJerk / validMeasurements).coerceIn(0.0, 1.0)
        } else {
            0.0
        }
    }

    private fun calculateJerk(
        x: Double, y: Double, z: Double,
        prevX: Double, prevY: Double, prevZ: Double,
        prevPrevX: Double, prevPrevY: Double, prevPrevZ: Double
    ): Double {
        val dt = 1.0 / 30.0 // Assuming 30fps
        val dx = (x - 2 * prevX + prevPrevX) / (dt * dt)
        val dy = (y - 2 * prevY + prevPrevY) / (dt * dt)
        val dz = (z - 2 * prevZ + prevPrevZ) / (dt * dt)
        return Math.sqrt(dx * dx + dy * dy + dz * dz)
    }

    private fun calculateBalanceScore(motionData: Map<*, *>): Double {
        try {
            val joints = motionData["joints"] as? Map<*, *> ?: return 0.0
            
            // Safely get joint positions with null checks
            val ankleLeft = joints["leftAnkle"] as? Map<*, *> ?: return 0.0
            val ankleRight = joints["rightAnkle"] as? Map<*, *> ?: return 0.0
            val hip = joints["hip"] as? Map<*, *> ?: return 0.0
            
            // Safe extraction of coordinates with null checks
            val ankleLeftX = ankleLeft["x"] as? Double ?: return 0.0
            val ankleLeftY = ankleLeft["y"] as? Double ?: return 0.0
            val ankleRightX = ankleRight["x"] as? Double ?: return 0.0
            val ankleRightY = ankleRight["y"] as? Double ?: return 0.0
            val hipX = hip["x"] as? Double ?: return 0.0
            val hipY = hip["y"] as? Double ?: return 0.0
            
            // Calculate center of mass (COM) relative to hip position
            val comX = hipX
            val comY = hipY
            
            // Calculate support polygon area (area between feet)
            val supportArea = calculatePolygonArea(listOf(
                ankleLeftX, ankleLeftY,
                ankleRightX, ankleRightY
            ))
            
            if (supportArea == 0.0) return 0.0
            
            // Calculate distance from COM to support polygon center
            val supportCenterX = (ankleLeftX + ankleRightX) / 2
            val supportCenterY = (ankleLeftY + ankleRightY) / 2
            val comOffset = Math.sqrt(
                Math.pow(comX - supportCenterX, 2.0) + 
                Math.pow(comY - supportCenterY, 2.0)
            )
            
            // Combine factors for balance score
            val normalizedOffset = 1.0 - (comOffset / supportArea).coerceIn(0.0, 1.0)
            return normalizedOffset
        } catch (e: Exception) {
            return 0.0
        }
    }

    private fun calculatePolygonArea(points: List<Double>): Double {
        try {
            if (points.size < 4) return 0.0
            
            var area = 0.0
            for (i in 0 until points.size step 2) {
                val j = (i + 2) % points.size
                area += points[i] * points[j + 1] - points[j] * points[i + 1]
            }
            return Math.abs(area) / 2.0
        } catch (e: Exception) {
            return 0.0
        }
    }
} 