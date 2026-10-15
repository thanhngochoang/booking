package com.paditech.mvpbase.common.utils.get_file;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.fragment.app.FragmentManager;
import androidx.core.content.ContextCompat;
import android.util.Log;
import android.webkit.MimeTypeMap;
import android.widget.ImageView;


import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.Date;

/**
 * Created by ThanhNgocHoang on 9/20/2017.
 */

public class GetFileManager {
    public static final int PERMISSION_STORAGE = 101;
    public static final int SETTING_STORAGE = 301;
    public static final int OPEN_SELECT_FILE = 201;

    private MVPActivity mActivity;
    private MVPFragment mFragment;

    private String mFileSelected;
    private GetFileListener mGetFileListener;

    public GetFileManager(MVPActivity mActivity, ImageView imageView) {
        this.mActivity = mActivity;
    }

    public GetFileManager(MVPFragment mFragment, ImageView imageView) {
        this.mFragment = mFragment;
    }

    public GetFileManager(MVPActivity mActivity) {
        this(mActivity, null);
    }

    public GetFileManager(MVPFragment mFragment) {
        this(mFragment, null);
    }

    public void setmGetFileListener(GetFileListener mGetFileListener) {
        this.mGetFileListener = mGetFileListener;
    }

    public Activity getActivity() {
        if (mActivity != null) return mActivity;
        if (mFragment != null) return mFragment.getActivity();
        return null;
    }

    public Context getContext() {
        if (mActivity != null) return mActivity;
        if (mFragment != null) return mFragment.getContext();
        return null;
    }

    public void onGetFile(GetFileListener getFileListener) {
        try {
            this.mGetFileListener = getFileListener;
            if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {

                // Should we show an explanation?
                if (mActivity != null) {
                    if (!ActivityCompat.shouldShowRequestPermissionRationale(getActivity(),
                            Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                        ActivityCompat.requestPermissions(mActivity,
                                new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                                PERMISSION_STORAGE);
                    } else {
                        notShouldShowPermission();
                    }
                } else if (mFragment != null) {
                    if (!mFragment.shouldShowRequestPermissionRationale(Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                        mFragment.requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                                PERMISSION_STORAGE);
                    } else {
                        notShouldShowPermission();
                    }
                }

            } else {
                openSelectFile();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void openSelectFile() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        Uri uri = Uri.parse(Environment.getExternalStorageDirectory().getPath());
        intent.setDataAndType(uri, "*/*");
        if (mActivity != null)
            mActivity.startActivityForResult(Intent.createChooser(intent, ""), OPEN_SELECT_FILE);
        else mFragment.startActivityForResult(Intent.createChooser(intent, ""), OPEN_SELECT_FILE);

    }

    private void notShouldShowPermission() {
        ((MVPActivity) getActivity()).showConfirmDialog(false, getContext().getString(R.string.mess_permission_storage),
                getContext().getString(R.string.ok), getContext().getString(R.string.cancel),
                new BaseDialog.OnPositiveClickListener() {
                    @Override
                    public void onPositiveClick() {
                        Intent intent = new Intent();
                        intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                        Uri uri = Uri.fromParts("package", getActivity().getPackageName(), null);
                        intent.setData(uri);
                        if (mActivity != null)
                            mActivity.startActivityForResult(intent, SETTING_STORAGE);
                        else mFragment.startActivityForResult(intent, SETTING_STORAGE);
                    }
                }, new BaseDialog.OnNegativeClickListener() {
                    @Override
                    public void onNegativeClick() {

                    }
                });
    }

    private FragmentManager getFragmentManager() {
        if (mActivity != null) return mActivity.getSupportFragmentManager();
        if (mFragment != null) return mFragment.getFragmentManager();
        return null;
    }


    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        try {
            switch (requestCode) {
                case PERMISSION_STORAGE:
                    if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                        new Handler().post(new Runnable() {
                            @Override
                            public void run() {
                                openSelectFile();
                            }
                        });
                    }
                    break;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        try {
            if (resultCode == Activity.RESULT_OK) {
                switch (requestCode) {
                    case OPEN_SELECT_FILE:
                        Uri uri = data.getData();
                        MimeTypeMap mime = MimeTypeMap.getSingleton();
                        String type = mime.getExtensionFromMimeType(getContext().getContentResolver().getType(uri));
                        String path;
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                            path = ImageUtil.getRealPathFromURI(uri, getContext());
                        } else {
                            path = ImageUtil.getImagePath(uri, getContext());
                        }
                        if (StringUtil.isEmpty(path)) {
                            path = ImageUtil.getFileFromStream(getContext(), uri, "test_file" + ImageUtil.SIMPLE_DATE_FORMAT.format(new Date()) + "." + type);
                        }
                        mFileSelected = path;
                        if (mGetFileListener != null) mGetFileListener.onSelectFile(mFileSelected);
                        Log.d("PATH", path + "----");
                        break;
                }
            }
            if (requestCode == SETTING_STORAGE) {
                if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        == PackageManager.PERMISSION_GRANTED) {
                    openSelectFile();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public interface GetFileListener {
        void onSelectFile(String image);
    }
}
