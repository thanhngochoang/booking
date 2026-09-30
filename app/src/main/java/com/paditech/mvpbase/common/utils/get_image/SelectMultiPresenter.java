package com.paditech.mvpbase.common.utils.get_image;

import android.app.Activity;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.provider.MediaStore;


import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;

import java.util.ArrayList;
import java.util.Collections;

/**
 * Created by ThanhNgocHoang on 8/9/2017.
 */

public class SelectMultiPresenter extends ActivityPresenter<SelectMultiContact.ViewOps> implements SelectMultiContact.PresenterViewOps {

    @Override
    public void onCreate() {
        super.onCreate();
        getAllPhotos(getView().getActivity());
    }

    @Override
    public void getAllPhotos(final Activity activity) {
        try {
            new AsyncTask<Void, Void, Void>() {
                @Override
                protected Void doInBackground(Void... voids) {
                    Uri uri;
                    ArrayList<String> listOfAllImages = new ArrayList<String>();
                    Cursor cursor;
                    int column_index_data, column_index_folder_name;
                    String PathOfImage = null;
                    uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;

                    String[] projection = {MediaStore.MediaColumns.DATA,
                            MediaStore.Images.Media.DATE_ADDED};

                    cursor = activity.getContentResolver().query(uri, projection, null,
                            null, null);

                    column_index_data = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA);
                    column_index_folder_name = cursor
                            .getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED);
                    while (cursor.moveToNext()) {
                        PathOfImage = cursor.getString(column_index_data);

                        listOfAllImages.add(PathOfImage);
                    }
                    Collections.reverse(listOfAllImages);

                    getView().onUpdatePhotos(listOfAllImages);
                    return null;
                }
            }.execute();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
