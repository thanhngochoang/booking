package com.paditech.mvpbase.common.utils;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.widget.ImageView;

import com.bumptech.glide.Glide;
import com.bumptech.glide.load.resource.bitmap.RoundedCorners;
import com.bumptech.glide.request.RequestOptions;
import com.paditech.mvpbase.R;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * <p/>
 * Created by Paditech on 1/9/2017.
 * Copyright (c) 2015 Paditech. All rights reserved.
 */

public class ImageUtil {
    public static final SimpleDateFormat SIMPLE_DATE_FORMAT = new SimpleDateFormat("yyyyMMdd_HHmmss");

    public static void loadImage(Context context, Object url, ImageView imageView) {
        try {
            Glide.with(context).load(url).apply(new RequestOptions().placeholder(R.color.gray_light).error(R.color.gray_light)).into(imageView);
        } catch (Exception e) {
            e.printStackTrace();
            imageView.setImageResource(R.color.gray_light);
        }
    }

    public static void loadImage(Context context, Object url, ImageView imageView, int place, int err) {
        try {
            Glide.with(context).load(url).apply(new RequestOptions().placeholder(place).error(err)).into(imageView);
        } catch (Exception e) {
            e.printStackTrace();
            imageView.setImageResource(err);
        }
    }

    public static void loadImageRounded(Context context, Object url, ImageView imageView, int radius) {
        try {
            Glide.with(context).load(url).apply(new RequestOptions().transform(new RoundedCorners(radius))).into(imageView);
        } catch (Exception e) {
            e.printStackTrace();
            imageView.setImageResource(R.color.gray_light);
        }
    }

    public static void loadImageRounded(Context context, Object url, ImageView imageView) {
        try {
            Glide.with(context).load(url).apply(new RequestOptions()
                    .transform(new RoundedCorners(context.getResources().getDimensionPixelSize(R.dimen.radius_image))))
                    .into(imageView);
        } catch (Exception e) {
            e.printStackTrace();
            imageView.setImageResource(R.color.gray_light);
        }
    }

    public static void loadImageRounded(Context context, Object url, ImageView imageView, int placeHolder, int err) {
        try {
            Glide.with(context).load(url).apply(new RequestOptions()
                    .placeholder(placeHolder)
                    .error(err)
                    .transform(new RoundedCorners(context.getResources().getDimensionPixelSize(R.dimen.radius_image))))
                    .into(imageView);
        } catch (Exception e) {
            e.printStackTrace();
            imageView.setImageResource(R.color.gray_light);
        }
    }

    public static String getImagePath(Uri uri, Context context) {
        if (context == null) return "";
        Cursor cursor = context.getContentResolver().query(uri, null, null, null, null);
        if (cursor == null) return uri.toString();
        cursor.moveToFirst();
        String document_id = cursor.getString(0);
        document_id = document_id.substring(document_id.lastIndexOf(":") + 1);
        cursor.close();

        cursor = context.getContentResolver().query(
                android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                null, MediaStore.Images.Media._ID + " = ? ", new String[]{document_id}, null);
        if (cursor == null) return uri.toString();
        if (cursor.moveToFirst()) {
            String path = cursor.getString(cursor.getColumnIndex(MediaStore.Images.Media.DATA));
            cursor.close();

            return path;
        } else {
            cursor.close();

            cursor = context.getContentResolver().query(
                    MediaStore.Images.Media.INTERNAL_CONTENT_URI,
                    null, MediaStore.Images.Media._ID + " = ? ", new String[]{document_id}, null);
            if (cursor == null) return uri.toString();
            if (cursor.moveToFirst()) {
                String path = cursor.getString(cursor.getColumnIndex(MediaStore.Images.Media.DATA));
                cursor.close();

                return path;
            } else {
                return null;
            }

        }
    }

    public static String getRealPathFromURI(Uri contentURI, Context context) {
        if (context == null) return "";
        String result;
        Cursor cursor = context.getContentResolver().query(contentURI, null, null, null, null);
        if (cursor == null || !cursor.moveToFirst()) { // Source is Dropbox or other similar local file path
            result = contentURI.getPath();
        } else {
            cursor.moveToFirst();
            int idx = cursor.getColumnIndex(MediaStore.Images.ImageColumns.DATA);
            result = cursor.getString(idx);
            cursor.close();
        }
        return result;
    }

    public static Bitmap rotateImage(Bitmap source, float angle) {
        Bitmap retVal;
        Matrix matrix = new Matrix();
        matrix.postRotate(angle);
        retVal = Bitmap.createBitmap(source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);

        return retVal;
    }

    public static String resizeImageFile(Context context, String filePath) {
        File photoDirectory = new File(Environment.getExternalStorageDirectory(), context.getPackageName());
        if (!photoDirectory.exists() && !photoDirectory.mkdirs()) {
            return "";
        }

        try {
            Bitmap b = BitmapFactory.decodeFile(filePath);
            if (b == null) return filePath;
            final File file = new File(photoDirectory, String.format("IMAGE_%s.png", SIMPLE_DATE_FORMAT.format(new Date())));

            ExifInterface ei = null;
            try {
                Bitmap main;
                ei = new ExifInterface(filePath);
                int orientation = ei.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_UNDEFINED);

                switch (orientation) {
                    case ExifInterface.ORIENTATION_ROTATE_90:
                        main = rotateImage(b, 90);
                        break;
                    case ExifInterface.ORIENTATION_ROTATE_180:
                        main = rotateImage(b, 180);
                        break;
                    case ExifInterface.ORIENTATION_ROTATE_270:
                        main = rotateImage(b, 270);
                        break;
                    default:
                        main = b;
                        break;
                }

                FileOutputStream fOut;
                try {
                    fOut = new FileOutputStream(file);
                    main.compress(Bitmap.CompressFormat.PNG, 100, fOut);
                    fOut.flush();
                    fOut.close();
                    b.recycle();
                    main.recycle();
                } catch (Exception e) {
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
            return file.getAbsolutePath();

        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }


    public static String getFileFromStream(Context context, Uri uri, String testID) {
        ContentResolver resolver = context.getContentResolver();
        File directory = new File(Environment.getExternalStorageDirectory(), context.getPackageName());
        if (!directory.exists() && !directory.mkdirs()) {
            return "";
        }
        File file = new File(directory, testID);
        try {
            FileOutputStream fileOutputStream = new FileOutputStream(file);
            InputStream inputStream = resolver.openInputStream(uri);
            int read = 0;
            byte[] bytes = new byte[1024];
            if (inputStream != null) {
                while ((read = inputStream.read(bytes)) != -1) {
                    fileOutputStream.write(bytes, 0, read);
                }
                return file.getAbsolutePath();
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}
