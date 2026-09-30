package com.paditech.mvpbase.common.service.upload_file;

import android.annotation.SuppressLint;
import android.app.IntentService;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.support.annotation.NonNull;
import android.support.v4.app.NotificationCompat;
import android.util.Log;
import android.widget.Toast;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.OnProgressListener;
import com.google.firebase.storage.UploadTask;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.event.UploadAlbumSuccess;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.PrefUtil;

import org.greenrobot.eventbus.EventBus;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * An {@link IntentService} subclass for handling asynchronous task requests in
 * a service on a separate handler thread.
 * <p>
 * TODO: Customize class - update intent actions, extra parameters and static
 * helper methods.
 */
public class UploadFileService extends IntentService {
    private final int NOTIFY_ID = 0;
    private NotificationManager mNotifyManager;
    private NotificationCompat.Builder mBuilder;
    private int mIndex;
    private ArrayList<String> mListFiles;
    private ArrayList<String> mListUrls;

    private static final String ALBUM_LIST_FILE = "ALBUM_LIST_FILE";
    private static final String ALBUM_NAME = "ALBUM_NAME";
    private static final String ALBUM_DESC = "ALBUM_DESC";
    private static final String ALBUM_LAT = "ALBUM_LAT";
    private static final String ALBUM_LONG = "ALBUM_LONG";
    private static final String ALBUM_ADDRESS = "ALBUM_ADDRESS";

    private String albumName, albumDesc, albumAddress;
    private double albumLat, albumLong;

    @SuppressLint("ServiceCast")
    public UploadFileService() {
        super("UploadFileService");
    }

    public static void startUploadFiles(Context context, Album album) {
        Intent intent = new Intent(context, UploadFileService.class);
        intent.putExtra(ALBUM_LIST_FILE, album.getAlbum_files());
        intent.putExtra(ALBUM_NAME, album.getAlbum_name());
        intent.putExtra(ALBUM_DESC, album.getAlbum_desc());
        intent.putExtra(ALBUM_ADDRESS, album.getAlbum_address());
        intent.putExtra(ALBUM_LAT, album.getAlbum_lat());
        intent.putExtra(ALBUM_LONG, album.getAlbum_long());
        context.startService(intent);
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        mListUrls = new ArrayList<>();
        mNotifyManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        mBuilder = new NotificationCompat.Builder(this);
        mBuilder.setContentTitle("Picture Upload")
                .setContentText("Download in progress")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(false)
                .setSmallIcon(R.drawable.ic_fb);
        if (intent != null) {
            albumDesc = intent.getStringExtra(ALBUM_DESC);
            albumName = intent.getStringExtra(ALBUM_NAME);
            albumAddress = intent.getStringExtra(ALBUM_ADDRESS);
            albumLat = intent.getDoubleExtra(ALBUM_LAT, 0f);
            albumLong = intent.getDoubleExtra(ALBUM_LONG, 0f);
            if (intent.getStringArrayListExtra(ALBUM_LIST_FILE) != null) {
                mIndex = 0;
                mListFiles = intent.getStringArrayListExtra(ALBUM_LIST_FILE);
                if (mListFiles != null && !mListFiles.isEmpty())
                    handleUploadFile(mListFiles.get(mIndex));
            }
        }
    }

    private void handleUploadFile(String text) {
        final Uri file = Uri.fromFile(new File(text));
        FirebaseStorage.getInstance()
                .getReference().child("albums").child(PrefUtil.getUid()).child(System.currentTimeMillis() + file.getLastPathSegment()).putFile(file).addOnCompleteListener(new OnCompleteListener<UploadTask.TaskSnapshot>() {
            @Override
            public void onComplete(@NonNull Task<UploadTask.TaskSnapshot> task) {
                if (task.isSuccessful()) {
                    Uri downloadUrl = task.getResult().getDownloadUrl();
                    Log.e("Download_URL", downloadUrl + "");
                    if (downloadUrl != null) {
                        mListUrls.add(downloadUrl.toString());
                    }
                    mIndex++;
                    if (mIndex < mListFiles.size())
                        handleUploadFile(mListFiles.get(mIndex));
                    else {
                        mBuilder.setProgress(100, 100, true);
                        mBuilder.setContentText("Upload images successful!");
                        mNotifyManager.cancel(NOTIFY_ID);
                        saveToDatabase();
                    }
                }

            }
        }).addOnProgressListener(new OnProgressListener<UploadTask.TaskSnapshot>() {
            @Override
            public void onProgress(UploadTask.TaskSnapshot taskSnapshot) {
                Log.e("Progress", (int) taskSnapshot.getTotalByteCount() + "---" + (int) taskSnapshot.getBytesTransferred());
                mBuilder.setProgress((int) taskSnapshot.getTotalByteCount(), (int) taskSnapshot.getBytesTransferred(), true);
                mBuilder.setContentText("Uploading " + (mIndex + 1) + "/" + mListFiles.size());
                mNotifyManager.notify(NOTIFY_ID, mBuilder.build());
            }
        });

    }

    private void saveToDatabase() {
        try {
            User photographer = PrefUtil.getUser(getApplicationContext());
            if(photographer == null) return;
            Map<String, Object> params = new HashMap<>();
            params.put("photographer_id", PrefUtil.getUid());
            params.put("photographer_name", photographer.getFull_name() + "");
            params.put("photographer_image", photographer.getAvatar() + "");
            params.put("album_name", albumName + "");
            params.put("album_desc", albumDesc + "");
            params.put("album_lat", albumLat);
            params.put("album_long", albumLong);
            params.put("album_files", mListUrls);
            params.put("album_address", albumAddress + "");

            FirebaseFirestore.getInstance().collection("albums").document().set(params);
            Toast.makeText(getApplicationContext(), "Congratulation! Upload Success", Toast.LENGTH_SHORT).show();
            /*ToastPopup.makeText(getApplicationContext(), "Congratulation! Upload Success", ToastPopup.ToastType.ALERT);*/
            EventBus.getDefault().post(new UploadAlbumSuccess());
        } catch (Exception e) {
            e.printStackTrace();
        }

    }
}
