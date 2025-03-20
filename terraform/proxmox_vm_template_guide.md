# **Proxmox VM Template Setup Guide**
This guide explains how to:

1. **Download the Debian 12 QCOW2 cloud image**
2. **Resize the image to 20GB**
3. **Fix the partition table and expand the filesystem**
4. **Create a Proxmox VM template**
5. **Clone a test VM to verify everything**

---

## **Step 1: Download the Debian 12 QCOW2 Image**
Run the following command to **download the latest Debian 12 cloud image**:

```bash
cd /var/lib/vz/template/qcow2
wget https://cdimage.debian.org/images/cloud/bookworm/20250210-2019/debian-12-genericcloud-amd64-20250210-2019.qcow2 -O debian-12-cloud.qcow2
```

Verify the download:
```bash
ls -lh debian-12-cloud.qcow2
```

✅ **Now we have the Debian 12 QCOW2 image in `/var/lib/vz/template/qcow2`.**

---

## **Step 2: Resize the QCOW2 Image to 20GB**
Resize the image before importing it into Proxmox:

```bash
qemu-img resize /var/lib/vz/template/qcow2/debian-12-cloud.qcow2 20G
```

Check the new size:

```bash
qemu-img info /var/lib/vz/template/qcow2/debian-12-cloud.qcow2
```

✅ **The QCOW2 image container is now 20GB, but partitions inside it are still small.**

---

## **Step 3: Fix the Partition Table and Expand the Filesystem**
### **1️⃣ Attach the QCOW2 Image as a Block Device**
We need to manually expand the root partition **inside** the QCOW2 image.

```bash
modprobe nbd max_part=8
qemu-nbd --connect=/dev/nbd0 /var/lib/vz/template/qcow2/debian-12-cloud.qcow2
lsblk /dev/nbd0
```

Expected output:
```
NAME      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nbd0       43:0    0   20G  0 disk 
├─nbd0p1   43:1    0  2.9G  0 part 
├─nbd0p14  43:14   0    3M  0 part 
└─nbd0p15  43:15   0  124M  0 part
```

**`nbd0p1` is too small (2.9GB), so we need to expand it.**

---

### **2️⃣ Resize the Partition Table**
Open `parted`:

```bash
parted /dev/nbd0
```

Inside `parted`, run:
```bash
print  # It may prompt to fix GPT, type: "fix"
resizepart 1 100%  # Expand partition 1 to use the full disk
quit
```

Verify with:

```bash
lsblk /dev/nbd0
```

✅ **Partition 1 (`nbd0p1`) should now be 20GB.**

---

### **3️⃣ Expand the Filesystem**
Now, resize the filesystem inside the partition.

#### **For ext4 Filesystem**
```bash
e2fsck -f /dev/nbd0p1
resize2fs /dev/nbd0p1
```

#### **For XFS Filesystem**
```bash
xfs_repair /dev/nbd0p1
xfs_growfs /dev/nbd0p1
```

✅ **The filesystem now uses the full 20GB disk.**

---

### **4️⃣ Detach the Image**
```bash
qemu-nbd --disconnect /dev/nbd0
rmmod nbd
```

✅ **The QCOW2 image is now fully resized and ready for Proxmox.**

---

## **Step 4: Create a Proxmox VM Template**
### **1️⃣ Create a New VM Without a Disk**
```bash
qm create 9000 --name debian-12-cloud-template --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
```

### **2️⃣ Import the Resized QCOW2 Disk**
```bash
qm importdisk 9000 /var/lib/vz/template/qcow2/debian-12-cloud.qcow2 extraqcow2 --format qcow2
```

### **3️⃣ Attach the Imported Disk**
```bash
qm set 9000 --virtio0 extraqcow2:9000/vm-9000-disk-0.qcow2
```

Verify:
```bash
qm config 9000
```

---

## **Step 5: Enable Cloud-Init**
To allow Terraform or other automation tools to configure VMs, enable **Cloud-Init**:

```bash
qm set 9000 --ide2 extraqcow2:cloudinit
qm set 9000 --boot c --bootdisk virtio0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --ciuser debian
qm set 9000 --sshkey /root/.ssh/id_rsa.pub
```

✅ **Now, this VM can be configured on first boot!**

---

## **Step 6: Convert the VM into a Template**
```bash
qm template 9000
```

Verify:
```bash
qm list
```
✔ **You should see VM 9000 as a template (`T`).**

---

## **Step 7: Clone a Test VM**
Now, test cloning a new VM from this template:

```bash
qm clone 9000 1001 --name k8s-controller --full true --storage extraqcow2
qm start 1001
```

Check inside the VM:
```bash
lsblk
df -h
```
✅ **If you see 20GB available, everything is perfect!**

---

# **Final Summary**
| Step | Action | Command |
|------|--------|---------|
| **1** | Download Debian 12 QCOW2 | `wget ...` |
| **2** | Resize QCOW2 container | `qemu-img resize ... 20G` |
| **3** | Attach image to nbd | `qemu-nbd --connect ...` |
| **4** | Resize partition | `parted /dev/nbd0` |
| **5** | Expand filesystem | `resize2fs /dev/nbd0p1` |
| **6** | Detach image | `qemu-nbd --disconnect ...` |
| **7** | Create Proxmox VM | `qm create 9000 ...` |
| **8** | Import and attach QCOW2 | `qm importdisk 9000 ...` |
| **9** | Enable Cloud-Init | `qm set 9000 ...` |
| **10** | Convert to Template | `qm template 9000` |
| **11** | Clone a Test VM | `qm clone 9000 ...` |

---

## **Next Steps**
Now that your **Proxmox template is ready**, Terraform can use it to **automate VM creation** for your cluster.

🚀 **Now you have a clean, automated process to set up Proxmox VMs from a cloud image!** Let me know if you need any tweaks! 🎯
