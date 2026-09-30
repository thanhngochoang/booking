package com.paditech.mvpbase.screen.create_album;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.os.Handler;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import com.google.android.gms.common.GooglePlayServicesRepairableException;
import com.google.android.gms.location.places.Place;
import com.google.android.gms.location.places.ui.PlacePicker;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.dialog.ToastPopup;
import com.paditech.mvpbase.common.event.UploadAlbumSuccess;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.service.upload_file.UploadFileService;
import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.common.utils.get_image.GetImageManager;
import com.paditech.mvpbase.screen.main.MainActivity;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.OnClick;
import butterknife.Unbinder;

import static android.app.Activity.RESULT_OK;

/**
 * Created by ThanhNgocHoang on 12/3/2017.
 */

public class CreateAlbumFragment extends MVPFragment<CreateAlbumContact.PresenterViewOps>
        implements CreateAlbumContact.ViewOps, AddImageAdapter.OnAddImageListener {
    private static int PLACE_PICKER_REQUEST = 100;

    @BindView(R.id.et_name)
    EditText etName;
    @BindView(R.id.et_desc)
    EditText etDesc;
    @BindView(R.id.btn_location)
    TextView btnLocation;
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;

    private AddImageAdapter mAddImageAdapter;
    private GetImageManager mGetImageManager;
    private Place mSelectedPlace;

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EventBus.getDefault().register(this);
    }

    @Override
    public void onDestroy() {
        EventBus.getDefault().unregister(this);
        super.onDestroy();
    }


    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onSuccessEvent(UploadAlbumSuccess uploadAlbumSuccess) {
        popBackStack();
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_create_album;
    }

    @Override
    protected void initView(View view) {
        CommonUtil.dismissSoftKeyboard(view, getActivityReference());
        mGetImageManager = new GetImageManager(this);
        mGetImageManager.setSelectType(GetImageManager.SelectType.MULTIPLE);
        mGetImageManager.setmMaxSelection(20);
        mGetImageManager.setmOnGetListPhotoSelectListener(new GetImageManager.OnGetListPhotoSelectListener() {
            @Override
            public void onPhotosSelect(ArrayList<String> photos) {
                mAddImageAdapter.addPhotos(photos);
            }
        });
        setupRecyclerView();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.create_album);
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return CreateAlbumPresenter.class;
    }

    @OnClick({R.id.btn_location, R.id.btn_create})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_location:
                try {
                    PlacePicker.IntentBuilder builder = new PlacePicker.IntentBuilder();
                    startActivityForResult(builder.build(getActivity()), PLACE_PICKER_REQUEST);
                } catch (GooglePlayServicesRepairableException e) {
                    e.printStackTrace();
                } catch (GooglePlayServicesNotAvailableException e) {
                    e.printStackTrace();
                }
                break;
            case R.id.btn_create:
                if (mSelectedPlace == null) return;
                if (mAddImageAdapter == null) return;
                Album album = new Album(etName.getText().toString().trim(), etDesc.getText().toString().trim(),
                        mSelectedPlace.getLatLng().latitude, mSelectedPlace.getLatLng().longitude,
                        mAddImageAdapter.getmListPhotos(), btnLocation.getText().toString().trim());
                showToast(getString(R.string.uploading_album));
                UploadFileService.startUploadFiles(getActivityContext(), album);
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (!isVisible())
                            popBackStack();
                    }
                }, ToastPopup.DURATION_DISMISS);
                break;
        }
    }

    private void setupRecyclerView() {
        mAddImageAdapter = new AddImageAdapter(getActivityReference());
        mAddImageAdapter.setmOnAddImageListener(this);
        recyclerView.setNestedScrollingEnabled(false);
        recyclerView.setLayoutManager(new GridLayoutManager(getActivityContext(), 3));
        recyclerView.setAdapter(mAddImageAdapter);
    }

    @Override
    public void onAddImageClick() {
        mGetImageManager.onAddImageFormLibrary();
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        mGetImageManager.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PLACE_PICKER_REQUEST) {
            if (resultCode == RESULT_OK) {
                Place place = PlacePicker.getPlace(getActivityContext(), data);
                if (place != null) {
                    this.mSelectedPlace = place;
                    btnLocation.setText(place.getName());
                }
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        mGetImageManager.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public void onResume() {
        super.onResume();
    }

    @Override
    public void onPause() {
        super.onPause();

    }

   /* private BroadcastReceiver receiver = new BroadcastReceiver() {

        @Override
        public void onReceive(Context context, Intent intent) {
            Bundle bundle = intent.getExtras();
            if (bundle != null) {
                String string = bundle.getString(DownloadService.FILEPATH);
                int resultCode = bundle.getInt(DownloadService.RESULT);
                if (resultCode == RESULT_OK) {
                    Toast.makeText(MainActivity.this,
                            "Download complete. Download URI: " + string,
                            Toast.LENGTH_LONG).show();
                    textView.setText("Download done");
                } else {
                    Toast.makeText(MainActivity.this, "Download failed",
                            Toast.LENGTH_LONG).show();
                    textView.setText("Download failed");
                }
            }
        }
    };*/
}
