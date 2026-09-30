package com.paditech.mvpbase.common.utils.get_image;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.provider.MediaStore;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.fragment.app.FragmentManager;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import android.widget.ImageView;

import com.paditech.mvpbase.BuildConfig;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.dialog.SelectImageDialog;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;

/**
 * Created by ThanhNgocHoang on 7/17/2017.
 */

public class GetImageManager {
    private String IMAGE_PATH;
    public static final String IMAGE_FILE_NAME = "photo_%s";
    public static final int PERMISSION_STORAGE = 101;
    public static final int PERMISSION_STORAGE_LIBRARY = 103;
    public static final int PERMISSION_CAMERA = 102;
    public static final int OPEN_CAMERA = 201;
    public static final int OPEN_LIBRARY = 202;
    public static final int OPEN_SELECT_MULTI = 203;
    public static final int SETTING_STORAGE = 301;
    public static final int SETTING_CAMRA = 302;
    private static final SimpleDateFormat SIMPLE_DATE_FORMAT = new SimpleDateFormat("yyyyMMdd_HHmmss");
    private MVPActivity mActivity;
    private MVPFragment mFragment;

    private String mImageFilePath;
    private ImageView mImageView;
    private SelectType mSelectType = SelectType.SINGLE;
    private int mMaxSelection = -1;
    private ArrayList<String> mListPhotoSelected;
    private OnGetListPhotoSelectListener mOnGetListPhotoSelectListener;
    private OnGetImageListener mOnGetImageListener;

    public void setmOnGetListPhotoSelectListener(OnGetListPhotoSelectListener mOnGetListPhotoSelectListener) {
        this.mOnGetListPhotoSelectListener = mOnGetListPhotoSelectListener;
    }

    public void setmOnGetImageListener(OnGetImageListener mOnGetImageListener) {
        this.mOnGetImageListener = mOnGetImageListener;
    }

    public interface OnGetListPhotoSelectListener {
        void onPhotosSelect(ArrayList<String> photos);
    }

    public interface OnGetImageListener {
        void onPhotoSelect(String photoPath);
    }

    public GetImageManager(MVPActivity mActivity, ImageView imageView) {
        this.mActivity = mActivity;
        this.mImageView = imageView;
        mListPhotoSelected = new ArrayList<>();
        EventBus.getDefault().register(this);
        this.IMAGE_PATH = getContext().getPackageName();
    }

    public GetImageManager(MVPFragment mFragment, ImageView imageView) {
        this.mImageView = imageView;
        this.mFragment = mFragment;
        mListPhotoSelected = new ArrayList<>();
        EventBus.getDefault().register(this);
        this.IMAGE_PATH = getContext().getPackageName();
    }

    public GetImageManager(MVPActivity mActivity) {
        this(mActivity, null);
    }

    public GetImageManager(MVPFragment mFragment) {
        this(mFragment, null);
    }

    public void setSelectType(SelectType mSelectType) {
        this.mSelectType = mSelectType;
    }

    public void setmMaxSelection(int mMaxSelection) {
        this.mMaxSelection = mMaxSelection;
    }

    public String getmImageFilePath() {
        return mImageFilePath;
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

    public void setmListPhotoSelected(ArrayList<String> mListPhotoSelected) {
        this.mListPhotoSelected = mListPhotoSelected;
    }

    @SuppressLint("StaticFieldLeak")
    @Subscribe(threadMode = ThreadMode.MAIN, sticky = true)
    public void onSelectMultiPhoto(final ArrayList<String> mListPhotos) {
        if (mListPhotos != null) {
            new AsyncTask<Void, Void, Void>() {
                @Override
                protected Void doInBackground(Void... voids) {
                    for (String link : mListPhotos) {
                        if (mListPhotoSelected.size() < mMaxSelection) {
                            mListPhotoSelected.add(link);
                        }
                    }
                    return null;
                }

                @Override
                protected void onPostExecute(Void aVoid) {
                    super.onPostExecute(aVoid);
                    if (mOnGetListPhotoSelectListener != null) {
                        mOnGetListPhotoSelectListener.onPhotosSelect(mListPhotoSelected);
                    }
                }
            }.execute();
        }
    }

    public void onAddImage() {
        try {
            if (mSelectType == SelectType.MULTIPLE) {
                if (mListPhotoSelected.size() >= mMaxSelection) {
                    return;
                }
            }
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
                showComfirmPickPhotoDialog();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void onAddImageFormLibrary() {
        try {
            if (mSelectType == SelectType.MULTIPLE) {
                if (mListPhotoSelected.size() >= mMaxSelection) {
                    return;
                }
            }
            if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {

                // Should we show an explanation?
                if (mActivity != null) {
                    if (!ActivityCompat.shouldShowRequestPermissionRationale(getActivity(),
                            Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                        ActivityCompat.requestPermissions(mActivity,
                                new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                                PERMISSION_STORAGE_LIBRARY);
                    }
                } else if (mFragment != null) {
                    if (!mFragment.shouldShowRequestPermissionRationale(Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                        mFragment.requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                                PERMISSION_STORAGE_LIBRARY);
                    }
                }

            } else {
                onPickImages();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
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

    public void onPickImages() {
        if (mSelectType == SelectType.MULTIPLE) {
            if (mActivity != null)
                mActivity.startActivityForResult(new Intent(getContext(), SelectMultiActivity.class), OPEN_SELECT_MULTI);
            else
                mFragment.startActivityForResult(new Intent(getContext(), SelectMultiActivity.class), OPEN_SELECT_MULTI);
        } else {
            if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.READ_EXTERNAL_STORAGE)
                    == PackageManager.PERMISSION_GRANTED) {
                Intent i = new Intent(
                        Intent.ACTION_PICK,
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
                if (mActivity != null)
                    mActivity.startActivityForResult(i, OPEN_LIBRARY);
                else mFragment.startActivityForResult(i, OPEN_LIBRARY);
            }
        }
    }

    public void showComfirmPickPhotoDialog() {
        try {
            SelectImageDialog selectImageDialog = SelectImageDialog.newInstance();
            selectImageDialog.setSelectImageDialogListenner(new SelectImageDialog.SelectImageDialogListenner() {
                @Override
                public void pickImage() {
                    onPickImages();
                }

                @Override
                public void takePhoto() {
                    if (ContextCompat.checkSelfPermission(getContext(), Manifest.permission.CAMERA)
                            != PackageManager.PERMISSION_GRANTED) {
                        if (mActivity != null) {
                            if (!ActivityCompat.shouldShowRequestPermissionRationale(getActivity(),
                                    Manifest.permission.CAMERA)) {
                                ActivityCompat.requestPermissions(mActivity,
                                        new String[]{Manifest.permission.CAMERA}, PERMISSION_CAMERA);
                            } else {
                                notShouldShowCameraPermission();
                            }
                        } else if (mFragment != null) {
                            if (!mFragment.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)) {
                                mFragment.requestPermissions(new String[]{Manifest.permission.CAMERA},
                                        PERMISSION_CAMERA);
                            } else {
                                notShouldShowCameraPermission();
                            }
                        }

                    } else {
                        onCaptureImage();
                    }
                }
            });
            if (getFragmentManager() != null)
                selectImageDialog.show(getFragmentManager(), selectImageDialog.getClass().getSimpleName());

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private FragmentManager getFragmentManager() {
        if (mActivity != null) return mActivity.getSupportFragmentManager();
        if (mFragment != null) return mFragment.getFragmentManager();
        return null;
    }

    private void notShouldShowCameraPermission() {
        ((MVPActivity) getActivity()).showConfirmDialog(false, getContext().getString(R.string.mess_permission_storage),
                getContext().getString(R.string.ok), getContext().getString(R.string.cancel), new BaseDialog.OnPositiveClickListener() {
                    @Override
                    public void onPositiveClick() {
                        Intent intent = new Intent();
                        intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                        Uri uri = Uri.fromParts("package", getActivity().getPackageName(), null);
                        intent.setData(uri);
                        if (mActivity != null)
                            mActivity.startActivityForResult(intent, SETTING_CAMRA);
                        else
                            mFragment.startActivityForResult(intent, SETTING_CAMRA);
                    }
                }, new BaseDialog.OnNegativeClickListener() {
                    @Override
                    public void onNegativeClick() {

                    }
                });
    }

    public void onCaptureImage() {
        try {
            if (ContextCompat.checkSelfPermission(getContext(), Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    == PackageManager.PERMISSION_GRANTED) {
                File photoDirectory = new File(Environment.getExternalStorageDirectory(), getContext().getPackageName());
                if (!photoDirectory.exists() && !photoDirectory.mkdirs()) {
                    return;
                }
                File photo = new File(photoDirectory, String.format(IMAGE_FILE_NAME, SIMPLE_DATE_FORMAT.format(new Date())));
                mImageFilePath = photo.getPath();
                Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                Uri mPhotoUri = FileProvider.getUriForFile(getContext(),
                        BuildConfig.APPLICATION_ID + ".provider",
                        photo);
                intent.putExtra(MediaStore.EXTRA_OUTPUT, mPhotoUri);
                if (mActivity != null)
                    mActivity.startActivityForResult(intent, OPEN_CAMERA);
                else
                    mFragment.startActivityForResult(intent, OPEN_CAMERA);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void resizeImage() {
        try {
            if (StringUtil.isEmpty(mImageFilePath)) return;
            mImageFilePath = ImageUtil.resizeImageFile(getContext(), mImageFilePath);
            switch (mSelectType) {
                case MULTIPLE:
                    if (mListPhotoSelected.size() < mMaxSelection)
                        if (mListPhotoSelected != null) {
                            mListPhotoSelected.add(mImageFilePath);
                            if (mOnGetListPhotoSelectListener != null)
                                mOnGetListPhotoSelectListener.onPhotosSelect(mListPhotoSelected);
                        }
                    break;
                case SINGLE:
                    if (mImageView != null) {
                        ImageUtil.loadImage(getContext(), new File(mImageFilePath), mImageView);
                    }
                    if (mOnGetImageListener != null)
                        mOnGetImageListener.onPhotoSelect(mImageFilePath);
                    break;
            }

        } catch (Exception e) {
            e.printStackTrace();
            mImageFilePath = null;
        }
    }

    public void getImageFromUri(Intent data) {
        try {
            Uri uri = data.getData();
            String path;
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                path = ImageUtil.getRealPathFromURI(uri, getContext());
            } else {
                path = ImageUtil.getImagePath(uri, getContext());
            }
            if (!StringUtil.isEmpty(path)) {
                mImageFilePath = path;
                if (mImageView != null) {
                    ImageUtil.loadImage(getContext(), new File(mImageFilePath), mImageView);
                }
                if (mSelectType == SelectType.SINGLE && mOnGetImageListener != null) {
                    mOnGetImageListener.onPhotoSelect(mImageFilePath);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        try {
            switch (requestCode) {
                case PERMISSION_STORAGE:
                    if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                        new Handler().post(new Runnable() {
                            @Override
                            public void run() {
                                showComfirmPickPhotoDialog();
                            }
                        });
                    }
                    break;

                case PERMISSION_STORAGE_LIBRARY:
                    if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                        new Handler().post(new Runnable() {
                            @Override
                            public void run() {
                                onPickImages();
                            }
                        });
                    }
                    break;
                case PERMISSION_CAMERA:
                    if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                        new Handler().post(new Runnable() {
                            @Override
                            public void run() {
                                onCaptureImage();
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
                    case GetImageManager.OPEN_CAMERA:
                        resizeImage();
                        break;
                    case GetImageManager.OPEN_LIBRARY:
                        getImageFromUri(data);
                        break;
                }
            }
            if (requestCode == SETTING_STORAGE) {
                if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        == PackageManager.PERMISSION_GRANTED) {
                    showComfirmPickPhotoDialog();
                }
            }
            if (requestCode == SETTING_CAMRA) {
                if (ContextCompat.checkSelfPermission(getActivity(), Manifest.permission.CAMERA)
                        == PackageManager.PERMISSION_GRANTED) {
                    onCaptureImage();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void onDestroy() {
        EventBus.getDefault().unregister(this);
    }

    public enum SelectType {
        SINGLE, MULTIPLE
    }
}
